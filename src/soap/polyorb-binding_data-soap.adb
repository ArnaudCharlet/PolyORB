------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--            P O L Y O R B . B I N D I N G _ D A T A . S O A P             --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                Copyright (C) 2001 Free Software Fundation                --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--              PolyORB is maintained by ENST Paris University.             --
--                                                                          --
------------------------------------------------------------------------------

--  Binding data concrete implementation for SOAP over HTTP.

--  $Id$

with Ada.Streams; use Ada.Streams;

with PolyORB.Any;
with PolyORB.Configuration;
with PolyORB.Initialization;
pragma Elaborate_All (PolyORB.Initialization);
with PolyORB.Filters;
with PolyORB.Filters.HTTP;
with PolyORB.ORB.Interface;
with PolyORB.Protocols;
with PolyORB.Protocols.SOAP_Pr;

with PolyORB.References.IOR;
with PolyORB.Representations.CDR;
--  XXX Unfortunate dependency on CDR code. Should provide
--  To_Any methods instead!!!!!! (but actually the Any in question
--  would be specific of how IORs are constructed) (but we could
--  say that the notion of IOR is cross-platform!).

with PolyORB.Transport.Sockets;
with PolyORB.Utils.Strings;

with AWS.URL;

package body PolyORB.Binding_Data.SOAP is

   use PolyORB.Buffers;
   use PolyORB.Filters.HTTP;
   use PolyORB.Objects;
   use PolyORB.Protocols.SOAP_Pr;
   use PolyORB.Representations.CDR;
   --  use PolyORB.Sockets;
   use PolyORB.Transport.Sockets;
   use PolyORB.Types;

   Preference : Profile_Preference;
   --  Global variable: the preference to be returned
   --  by Get_Profile_Preference for SOAP profiles.

   procedure Marshall_Socket
     (Buffer   : access Buffer_Type;
      Sock     : Sockets.Sock_Addr_Type);

   procedure Unmarshall_Socket
    (Buffer   : access Buffer_Type;
     Sock     : out Sockets.Sock_Addr_Type);
   --  XXX code duplicated from Binding_Data.IIOP, should be
   --  factored out.

   function To_Any (SA : Sockets.Sock_Addr_Type) return Any.Any;
   function From_Any (A : Any.Any) return Sockets.Sock_Addr_Type;

   procedure Initialize (P : in out SOAP_Profile_Type) is
   begin
      P.Object_Id := null;
   end Initialize;

   procedure Adjust (P : in out SOAP_Profile_Type) is
   begin
      if P.Object_Id /= null then
         P.Object_Id := new Object_Id'(P.Object_Id.all);
      end if;
   end Adjust;

   procedure Finalize (P : in out SOAP_Profile_Type) is
   begin
      Free (P.Object_Id);
   end Finalize;

   procedure Bind_Profile
     (Profile : SOAP_Profile_Type;
      TE      : out Transport.Transport_Endpoint_Access;
      Filter  : out Components.Component_Access)
   is
      use PolyORB.Components;
      use PolyORB.Protocols;
      use PolyORB.Sockets;
      use PolyORB.Filters;

      Sock : Socket_Type;
      Remote_Addr : Sock_Addr_Type := Profile.Address;
      Pro  : aliased SOAP_Protocol;
      Htt  : aliased HTTP_Filter_Factory;

      Prof : Profile_Access := new SOAP_Profile_Type;
      --  This Profile_Access is stored in the created
      --  GIOP_Session, and free'd when the session is finalised.

      TProf : SOAP_Profile_Type
        renames SOAP_Profile_Type (Prof.all);

   begin
      Create_Socket (Sock);
      Connect_Socket (Sock, Remote_Addr);
      TE := new Transport.Sockets.Socket_Endpoint;
      Create (Socket_Endpoint (TE.all), Sock);

      Chain_Factories ((0 => Htt'Unchecked_Access,
                        1 => Pro'Unchecked_Access));

      Filter := Component_Access
        (HTTP.Create_Filter_Chain (Htt'Unchecked_Access));
      --  Filter must be an access to the lowest filter in
      --  the stack (the HTTP filter in the case of SOAP/HTTP).

      TProf.Address := Profile.Address;
      TProf.Object_Id := Profile.Object_Id;
      Adjust (TProf);

      --  The caller will invoke Register_Endpoint on TE.
   end Bind_Profile;

   function Get_Profile_Tag
     (Profile : SOAP_Profile_Type)
     return Profile_Tag
   is
      pragma Warnings (Off);
      pragma Unreferenced (Profile);
      pragma Warnings (On);
   begin
      return Tag_SOAP;
   end Get_Profile_Tag;

   function Get_Profile_Preference
     (Profile : SOAP_Profile_Type)
     return Profile_Preference
   is
      pragma Warnings (Off);
      pragma Unreferenced (Profile);
      pragma Warnings (On);
   begin
      return Preference;
   end Get_Profile_Preference;

   function Get_URI_Path
     (Profile : SOAP_Profile_Type)
     return Types.String is
   begin
      return Profile.URI_Path;
   end Get_URI_Path;

   procedure Create_Factory
     (PF : out SOAP_Profile_Factory;
      TAP : Transport.Transport_Access_Point_Access;
      ORB : Components.Component_Access) is
   begin
      PF.Address := Address_Of (Socket_Access_Point (TAP.all));
      PF.ORB := ORB;
   end Create_Factory;

   function Create_Profile
     (PF  : access SOAP_Profile_Factory;
      TAP : Transport.Transport_Access_Point_Access;
      Oid : Objects.Object_Id)
     return Profile_Access
   is
      use PolyORB.Transport.Sockets;

      Result : constant Profile_Access
        := new SOAP_Profile_Type;

      TResult : SOAP_Profile_Type
        renames SOAP_Profile_Type (Result.all);

   begin
      TResult.Object_Id := new Object_Id'(Oid);
      TResult.Address   := Address_Of
        (Socket_Access_Point (TAP.all));

      declare
         PF_ORB : PolyORB.Components.Component_Access renames PF.ORB;

         Oid_Translate : constant ORB.Interface.Oid_Translate
           := (PolyORB.Components.Message with Oid => TResult.Object_Id);
         TOid_Translate : PolyORB.Components.Message'Class
           renames PolyORB.Components.Message'Class (Oid_Translate);
         M : constant PolyORB.Components.Message'Class
           := PolyORB.Components.Emit
           (Port => PF_ORB,  Msg => TOid_Translate);
         TM : ORB.Interface.URI_Translate renames
           ORB.Interface.URI_Translate (M);
      begin
         TResult.URI_Path := TM.Path;
      end;

      return  Result;
   end Create_Profile;

   function Create_Profile
     (URI : Types.String)
     return Profile_Access
   is
      use AWS.URL;
      use Sockets;

      URL : AWS.URL.Object
        := Parse (To_Standard_String (URI));

      Result : constant Profile_Access
        := new SOAP_Profile_Type;

      TResult : SOAP_Profile_Type
        renames SOAP_Profile_Type (Result.all);
   begin
      Normalize (URL);
      begin
         TResult.Address.Addr := Inet_Addr (Server_Name (URL));
      exception
         when Socket_Error =>
            TResult.Address.Addr
              := Addresses (Get_Host_By_Name (Server_Name (URL)), 1);
      end;

      TResult.Address.Port := Port_Type (Positive'(Port (URL)));

      TResult.URI_Path := To_PolyORB_String (AWS.URL.URI (URL));
      --  XXX do we need to fill in TResult.Oid ?

      return Result;
   end Create_Profile;

   function Is_Local_Profile
     (PF : access SOAP_Profile_Factory;
      P : Profile_Access) return Boolean
   is
      use type PolyORB.Sockets.Sock_Addr_Type;
   begin
      return P.all in SOAP_Profile_Type
        and then SOAP_Profile_Type (P.all).Address = PF.Address;
   end Is_Local_Profile;

   --------------------------------
   -- Marshall_SOAP_Profile_Body --
   --------------------------------

   procedure Marshall_SOAP_Profile_Body
     (Buf     : access Buffer_Type;
      Profile : Profile_Access)
   is
      use PolyORB.Buffers;

      SOAP_Profile : SOAP_Profile_Type renames SOAP_Profile_Type (Profile.all);
      Profile_Body : Buffer_Access := new Buffer_Type;

   begin
      --  A Tag_SOAP Profile Body is an encapsulation.
      Start_Encapsulation (Profile_Body);

      --  Marshalling of a socket address
      Marshall_Socket (Profile_Body, SOAP_Profile.Address);

      --  Marshalling of the Object Id
      Marshall
        (Profile_Body, Stream_Element_Array
         (SOAP_Profile.Object_Id.all));

      Marshall (Profile_Body, SOAP_Profile.URI_Path);

      --  Marshall the Profile_Body into IOR.
      Marshall (Buf, Encapsulate (Profile_Body));
      Release (Profile_Body);
   end Marshall_SOAP_Profile_Body;

   ----------------------------------
   -- Unmarshall_SOAP_Profile_Body --
   ----------------------------------

   function Unmarshall_SOAP_Profile_Body
     (Buffer       : access Buffer_Type)
     return Profile_Access
   is
      Profile_Body   : aliased Encapsulation := Unmarshall (Buffer);
      Profile_Buffer : Buffer_Access := new Buffers.Buffer_Type;
      --  Length         : CORBA.Long;
      Result         : Profile_Access := new SOAP_Profile_Type;
      TResult        : SOAP_Profile_Type
        renames SOAP_Profile_Type (Result.all);

   begin
      Decapsulate (Profile_Body'Access, Profile_Buffer);

      Unmarshall_Socket (Profile_Buffer, TResult.Address);

      declare
         Str  : aliased Stream_Element_Array :=
           Unmarshall (Profile_Buffer);
      begin
         TResult.Object_Id := new Object_Id'(Object_Id (Str));
      end;
      TResult.URI_Path := Unmarshall (Profile_Buffer);
      Release (Profile_Buffer);
      return Result;

   end Unmarshall_SOAP_Profile_Body;

   procedure Marshall_Socket
     (Buffer   : access Buffer_Type;
      Sock     : Sockets.Sock_Addr_Type)
   is
   begin
      Marshall_From_Any (Buffer, To_Any (Sock));
   end Marshall_Socket;

   TC_Sock_Addr : Any.TypeCode.Object;

   procedure Initialize is
      use PolyORB.Any;
      use PolyORB.Any.TypeCode;

      Preference_Offset : constant String
        := PolyORB.Configuration.Get_Conf
        (Section => "soap",
         Key     => "polyorb.binding_data.soap.preference",
         Default => "0");

      function "+" (S : Standard.String) return Types.String
        renames To_PolyORB_String;
   begin
      Preference := Preference_Default + Profile_Preference'Value
        (Preference_Offset);

      TC_Sock_Addr := Any.TypeCode.TC_Struct;
      Add_Parameter (TC_Sock_Addr, To_Any (+"sock_addr"));
      Add_Parameter (TC_Sock_Addr, To_Any (+"IDL:sock_addr:1.0"));
      Add_Parameter (TC_Sock_Addr, To_Any (Any.TC_String));
      Add_Parameter (TC_Sock_Addr, To_Any (+"host"));
      Add_Parameter (TC_Sock_Addr, To_Any (Any.TC_Unsigned_Short));
      Add_Parameter (TC_Sock_Addr, To_Any (+"port"));

      References.IOR.Register
        (Tag_SOAP,
         Marshall_SOAP_Profile_Body'Access,
         Unmarshall_SOAP_Profile_Body'Access);
   end Initialize;

   function To_Any (SA : Sockets.Sock_Addr_Type) return Any.Any is
      use PolyORB.Any;

      Result : Any.Any := Get_Empty_Any_Aggregate (TC_Sock_Addr);
   begin
      Any.Add_Aggregate_Element
        (Result, To_Any (To_PolyORB_String (Sockets.Image (SA.Addr))));
      Any.Add_Aggregate_Element
        (Result, To_Any (Types.Unsigned_Short (SA.Port)));
      return Result;
   end To_Any;

   function From_Any (A : Any.Any) return Sockets.Sock_Addr_Type is
      use Sockets;

      Host : constant Types.String
        := Any.From_Any (Any.Get_Aggregate_Element
                         (A, Any.TC_String, 0));
      Port : constant Types.Unsigned_Short
        := Any.From_Any (Any.Get_Aggregate_Element
                         (A, Any.TC_Unsigned_Short, 1));
   begin
      return Sockets.Sock_Addr_Type'
        (Family => Family_Inet,
         Addr   => Inet_Addr (To_Standard_String (Host)),
         Port   => Port_Type (Port));
   end From_Any;

   procedure Unmarshall_Socket
    (Buffer   : access Buffer_Type;
     Sock     : out Sockets.Sock_Addr_Type)
   is
      A : Any.Any := Any.Get_Empty_Any (TC_Sock_Addr);
   begin
      Unmarshall_To_Any (Buffer, A);
      Sock := From_Any (A);
   end Unmarshall_Socket;

   -----------
   -- Image --
   -----------

   function Image (Prof : SOAP_Profile_Type) return String is
      Result : PolyORB.Types.String := To_PolyORB_String
        ("Address: " & Sockets.Image (Prof.Address));
   begin
      if Prof.Object_Id /= null then
         Append
           (Result,
            ", Object_Id : " & PolyORB.Objects.Image
            (Prof.Object_Id.all));
      else
         Append (Result, ", object id not available.");
      end if;
      return To_Standard_String (Result);
   end Image;

   function To_URI (Prof : SOAP_Profile_Type) return String is
   begin
      return "http://" & Sockets.Image (Prof.Address)
        & To_Standard_String (Prof.URI_Path);
   end To_URI;

   use PolyORB.Initialization;
   use PolyORB.Initialization.String_Lists;
   use PolyORB.Utils.Strings;

begin
   Register_Module
     (Module_Info'
      (Name => +"binding_data.soap",
       Conflicts => Empty,
       Depends => Empty,
       Provides => Empty,
       Init => Initialize'Access));
end PolyORB.Binding_Data.SOAP;
