with System;
with Ada.Strings.Unbounded;
with Ada.Exceptions;
with Broca.Types; use Broca.Types;
with CORBA; use CORBA;
with CORBA.Iop;
with Sockets.Thin;
with Sockets.Constants;
with Interfaces.C;
with Interfaces.C.Strings;
with Broca.Exceptions;
with Broca.Marshalling;
with Broca.Giop;
with Broca.Stream;
with Broca.Flags;
with Broca.Server;
with Ada.Text_IO;
pragma Elaborate_All (Broca.Exceptions);
pragma Elaborate_All (Broca.Server);
pragma Elaborate_All (CORBA);

with Broca.Debug;
pragma Elaborate_All (Broca.Debug);

package body Broca.Inet_Server is
   Flag : constant Natural := Broca.Debug.Is_Active ("broca.orb");
   procedure O is new Broca.Debug.Output (Flag);

   My_Addr : Sockets.Thin.In_Addr;
   Iiop_Host : CORBA.String;
   Iiop_Port : CORBA.Unsigned_Short;
   Listening_Socket : Interfaces.C.int;

   --  Find an IPv4 address for this host.
   procedure Get_Host_Address;

   function Htons (Val : Natural) return Interfaces.C.unsigned_short;
   function Ntohs (Val : Interfaces.C.unsigned_short) return Natural;

   procedure Initialize;

   --  Calling this function will cause the BOA to start accepting requests
   --  from other address spaces.
   procedure Wait_Fd_Request (Buffer : in out Buffer_Descriptor);

   --  Convert an IN_ADDR to the decimal string representation.
   function In_Addr_To_Str (Addr : Sockets.Thin.In_Addr) return String;

   function In_Addr_To_Str (Addr : Sockets.Thin.In_Addr) return String
   is
      function Image (Val : Interfaces.C.unsigned_char) return String;
      function Image (Val : Interfaces.C.unsigned_char) return String is
         Res : String := Interfaces.C.unsigned_char'Image (Val);
      begin
         return Res (Res'First + 1 .. Res'Last);
      end Image;
   begin
      return Image (Addr.S_B1) & '.' & Image (Addr.S_B2) & '.' &
        Image (Addr.S_B3) & '.' & Image (Addr.S_B4);
   end In_Addr_To_Str;

   procedure Get_Host_Address is
      use Interfaces.C;
      use Sockets.Thin;
      Host_Name_Acc : Interfaces.C.Strings.char_array_access;
      Host_Name_Ptr : Interfaces.C.Strings.chars_ptr;
      Len : int;
      Host : Hostent_Access;
   begin
      --  Get the name of the host.
      Host_Name_Acc := new Interfaces.C.char_array (0 .. 63);
      Host_Name_Ptr :=
        Interfaces.C.Strings.To_Chars_Ptr (Host_Name_Acc, False);
      Len := C_Gethostname (Host_Name_Ptr, Host_Name_Acc.all'Length);
      if Len < 0 or Len > Host_Name_Acc.all'Length then
         Broca.Exceptions.Raise_Comm_Failure;
      end if;

      --  Get the host entry corresponding to the name.
      Host := C_Gethostbyname (Host_Name_Ptr);
      if Host = null then
         Broca.Exceptions.Raise_Comm_Failure;
      end if;

      --  Get the first IP address.
      My_Addr := In_Addr_Access_Pointers.Value (Host.H_Addr_List)(1).all;
   end Get_Host_Address;

   function Htons (Val : Natural) return Interfaces.C.unsigned_short is
   begin
      if Broca.Marshalling.Is_Little_Endian then
         return Interfaces.C.unsigned_short
           ((Val / 256) + (Val mod 256) * 256);
      else
         return Interfaces.C.unsigned_short (Val);
      end if;
   end Htons;

   function Ntohs (Val : Interfaces.C.unsigned_short) return Natural
   is
      use Interfaces.C;
   begin
      if Broca.Marshalling.Is_Little_Endian then
         return Natural
           ((Val / 256) + (Val mod 256) * 256);
      else
         return Natural (Val);
      end if;
   end Ntohs;

   use Sockets.Thin;
   use Broca.Stream;

   Polls : Pollfd_Array (1 .. 10);
   Streams : Stream_Acc_Array (2 .. 10) := (others => null);
   Nbr_Fd : Integer := 0;
   Fd_Server_Id : Broca.Server.Server_Id_Type;
   Fd_Pos : Integer;

   --  Create a listening socket.
   procedure Initialize is
      use Sockets.Thin;
      use Sockets.Constants;
      use Interfaces.C;
      Sock : Interfaces.C.int;
      Sock_Name : Sockaddr_In;
      Sock_Name_Size : aliased Interfaces.C.int;
   begin
      --  Create the socket.
      Sock := C_Socket (Af_Inet, Sock_Stream, 0);
      if Sock = Failure then
         Broca.Exceptions.Raise_Comm_Failure;
      end if;

      --  Find an address for this host.
      Get_Host_Address;

      --  Bind this socket.
      --  Do not use the default address (security issue), but the address
      --  found.
      Sock_Name.Sin_Family := Af_Inet;
      Sock_Name.Sin_Port := Htons (Broca.Flags.Port);
      Sock_Name.Sin_Addr := My_Addr;
      if C_Bind (Sock, Sock_Name'Address, Sock_Name'Size / 8) = Failure then
         C_Close (Sock);
         Broca.Exceptions.Raise_Comm_Failure;
      end if;

      --  Listen
      if C_Listen (Sock, 8) = Failure then
         C_Close (Sock);
         Broca.Exceptions.Raise_Comm_Failure;
      end if;

      --  Retrieve the port.
      Sock_Name_Size := Sock_Name'Size / 8;
      if C_Getsockname (Sock, Sock_Name'Address, Sock_Name_Size'Access)
        = Failure
      then
         C_Close (Sock);
         Broca.Exceptions.Raise_Comm_Failure;
      end if;
      Iiop_Port := CORBA.Unsigned_Short (Sock_Name.Sin_Port);
      --  Network to host byte order convertion.
      if Broca.Marshalling.Is_Little_Endian then
         Iiop_Port := (Iiop_Port / 256) + (Iiop_Port mod 256) * 256;
      end if;

      Listening_Socket := Sock;

      --  Stringification of the address.
      declare
         use Ada.Text_IO;
         Addr_Str : String := In_Addr_To_Str (My_Addr);
      begin
         Iiop_Host := CORBA.To_CORBA_String (Addr_Str);
         if Broca.Flags.Verbose then
            Put ("listening on host: ");
            Put (Addr_Str);
            Put (", port: ");
            Put_Line (CORBA.Unsigned_Short'Image (Iiop_Port));
         end if;
      end;

      Polls (1).Fd := Listening_Socket;
      Polls (1).Events := Pollin;
      Nbr_Fd := 1;
      Fd_Pos := 1;
   end Initialize;

   --  Calling this function will cause the BOA to start accepting requests
   --  from other address spaces.
   procedure Wait_Fd_Request (Buffer : in out Buffer_Descriptor)
   is
      use Broca.Marshalling;
      use Sockets.Constants;
      use Interfaces.C;
      Res : C.int;
      Sock : Interfaces.C.int;
      Sock_Name : Sockaddr_In;
      Size : aliased C.int;
      The_Fd_Pos : Integer;
   begin
      Broca.Server.Log ("poll on fd");
      << Again >> null;

      if Fd_Pos > Nbr_Fd then
         Res := C_Poll (Polls'Address, C.unsigned_long (Nbr_Fd), -1);
         if Res = 0 then
            --  Timeout
            return;
         elsif Res < 0 then
            Broca.Exceptions.Raise_Comm_Failure;
         end if;
         Fd_Pos := 1;
      end if;

      if Fd_Pos = 1 and then Polls (1).Revents >= Pollin then
         --  Accepting a connection.
         Size := 0;
         Size := Sock_Name'Size / 8;
         Sock :=
           C_Accept (Listening_Socket, Sock_Name'Address, Size'Access);
         if Sock = Failure then
            Broca.Exceptions.Raise_Comm_Failure;
         end if;

         Broca.Server.Log
           ("accepting a connection of fd" & C.int'Image (Sock)
            & " from " & In_Addr_To_Str (Sock_Name.Sin_Addr)
            & " port" & Natural'Image (Ntohs (Sock_Name.Sin_Port)));

         Nbr_Fd := Nbr_Fd + 1;
         Polls (Nbr_Fd).Fd := Sock;
         Polls (Nbr_Fd).Events := Pollin;
         Polls (Nbr_Fd).Revents := 0;
         Streams (Nbr_Fd) := Broca.Stream.Create_Fd_Stream (Sock);
         Fd_Pos := 2;
      end if;

      loop
         exit when Polls (Fd_Pos).Revents >= Pollin;
         Fd_Pos := Fd_Pos + 1;
         if Fd_Pos > Nbr_Fd then
            goto Again;
         end if;
      end loop;

      Sock := Polls (Fd_Pos).Fd;

      --  Receive a message header
      Increase_Buffer_And_Clear_Pos
        (Buffer, Broca.Giop.Message_Header_Size);
      Res := C_Recv (Sock, Buffer.Buffer.all'Address,
                     Broca.Giop.Message_Header_Size, 0);
      if Res <= 0 then
         if Broca.Flags.Log then
            if Res < 0 then
               Broca.Server.Log
                 ("error " & C.int'Image (Res)
                  & " on fd" & C.int'Image (Sock));
            else
               Broca.Server.Log
                 ("connection closed on fd" & C.int'Image (Sock));
            end if;
         end if;

         --  The fd was closed
         C_Close (Sock);
         --  FIXME: remove suspended requests.
         Broca.Stream.Unchecked_Deallocation (Streams (Fd_Pos));
         Streams (Fd_Pos) := Streams (Nbr_Fd);
         Streams (Nbr_Fd) := null;
         Polls (Fd_Pos) := Polls (Nbr_Fd);
         Nbr_Fd := Nbr_Fd - 1;
         goto Again;
      elsif Res /= Broca.Giop.Message_Header_Size then
         Broca.Exceptions.Raise_Comm_Failure;
      end if;

      --  The message was accepted.
      The_Fd_Pos := Fd_Pos;
      Fd_Pos := Fd_Pos + 1;
      --  Prevent poll from accepting messages from this fd, since it is
      --  locked.
      --  It is locked because data was not yet read.
      Polls (The_Fd_Pos).Events := 0;
      Broca.Server.New_Request (Fd_Server_Id);
      Broca.Server.Log
        ("message received from fd" & Interfaces.C.int'Image (Sock));
      Broca.Stream.Lock_Receive (Streams (The_Fd_Pos));
      Broca.Server.Handle_Message (Streams (The_Fd_Pos), Buffer);
      Polls (The_Fd_Pos).Events := Pollin;
      return;
   end Wait_Fd_Request;

   type Fd_Server_Type is new Broca.Server.Server_Type with null record;
   procedure Perform_Work (Server : access Fd_Server_Type;
                           Buffer : in out Broca.Types.Buffer_Descriptor);
   procedure Marshall_Size_Profile
     (Server : access Fd_Server_Type;
      Ior : in out Broca.Types.Buffer_Descriptor;
      Object_Key : Broca.Types.Buffer_Descriptor);
   procedure Marshall_Profile (Server : access Fd_Server_Type;
                               Ior : in out Broca.Types.Buffer_Descriptor;
                               Object_Key : Broca.Types.Buffer_Descriptor);

   procedure Perform_Work (Server : access Fd_Server_Type;
                           Buffer : in out Broca.Types.Buffer_Descriptor) is
   begin
      Wait_Fd_Request (Buffer);
   end Perform_Work;

   procedure Marshall_Size_Profile (Server : access Fd_Server_Type;
                                    Ior : in out Broca.Types.Buffer_Descriptor;
                                    Object_Key : Broca.Types.Buffer_Descriptor)
   is
      use Broca.Marshalling;
   begin
      --  tag
      Marshall_Size_Unsigned_Long (Ior);
      --  profile_data length
      Marshall_Size_Unsigned_Long (Ior);
      --  flag
      Marshall_Size_Octet (Ior);

      --  Version is 2 bytes.
      Marshall_Size_Octet (Ior);
      Marshall_Size_Octet (Ior);
      --  Host string.
      Marshall_Size (Ior, Iiop_Host);
      --  Port
      Marshall_Size_Unsigned_Short (Ior);
      Marshall_Align_4 (Ior);
      --  key.
      Marshall_Size_Append (Ior, Object_Key);
   end Marshall_Size_Profile;

   procedure Marshall_Profile (Server : access Fd_Server_Type;
                               Ior : in out Broca.Types.Buffer_Descriptor;
                               Object_Key : Broca.Types.Buffer_Descriptor)
   is
      use Broca.Marshalling;
      Length_Pos : Buffer_Index_Type;
      Pos : Buffer_Index_Type;
   begin
      Marshall (Ior, CORBA.Iop.Tag_Internet_Iop);
      Length_Pos := Ior.Pos;
      Marshall_Size_Unsigned_Long (Ior);
      Marshall (Ior, Is_Little_Endian);

      --  Version 1.0
      Marshall (Ior, CORBA.Octet'(1));
      Marshall (Ior, CORBA.Octet'(0));
      --  Host
      Marshall (Ior, Iiop_Host);
      --  Port
      Marshall (Ior, Iiop_Port);
      Marshall_Align_4 (Ior);
      --  object key
      Marshall_Append (Ior, Object_Key);

      Pos := Ior.Pos;
      Ior.Pos := Length_Pos;
      Marshall (Ior, CORBA.Unsigned_Long (Pos - Length_Pos - 4));
      Ior.Pos := Pos;
   end Marshall_Profile;

   type Fd_Server_Acc is access Fd_Server_Type;
   The_Fd_Server : Fd_Server_Acc;
begin
   Initialize;
   The_Fd_Server := new Fd_Server_Type;
   Broca.Server.Register
     (Broca.Server.Server_Acc (The_Fd_Server), Fd_Server_Id);

   --  There is always one request to handle: accepting a connection.
   Broca.Server.New_Request (Fd_Server_Id);
end Broca.Inet_Server;
