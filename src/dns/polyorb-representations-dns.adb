------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--          P O L Y O R B . R E P R E S E N T A T I O N S . D N S            --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2002-2010, Free Software Foundation, Inc.          --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 51 Franklin Street, Fifth    --
-- Floor, Boston, MA 02111-1301, USA.                                       --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------
   with Ada.Streams;
   with PolyORB.Initialization;
   with PolyORB.Log;
   with GNAT.Byte_Swapping;
   with PolyORB.Utils.Strings;
   with PolyORB.Utils.Buffers;
   with PolyORB.DNS.Helper;
   with PolyORB.Utils;
   pragma Elaborate_All (PolyORB.Utils.Buffers);

package body PolyORB.Representations.DNS is
   use Ada.Streams;
   use PolyORB.Any.TypeCode;
   use PolyORB.Log;
   use PolyORB.Errors;
   use PolyORB.Utils.Buffers;
   use GNAT.Byte_Swapping;
   use PolyORB.Utils;
   use PolyORB.DNS.Helper;
   package L is new PolyORB.Log.Facility_Log ("polyorb.representations.dns");
   procedure O (Message : String; Level : Log_Level := Debug)
     renames L.Output;
   function C (Level : Log_Level := Debug) return Boolean
     renames L.Enabled;

   procedure Marshall_From_Any
     (Buffer : Buffer_Access; Argument : Any.Any;
      Is_Reply : Types.Boolean) is
      current_Seq : rrSequence;
      current_rr : RR;
   begin
      pragma Debug (C, O ("Marshall_From_Any: enter"));
      current_Seq := From_Any (Argument);
      for J in 1 .. Length (current_Seq) loop
         current_rr := Get_Element (current_Seq, J);
         Marshall_DNS_String (Buffer, To_Standard_String (current_rr.rr_name));

         case current_rr.rr_type is
            when A =>
               Marshall (Buffer, A_Code);
               Marshall (Buffer, Default_Class_Code);
               if Is_Reply then
                  Marshall (Buffer, current_rr.TTL);
                  Marshall (Buffer, Types.Unsigned_Short
                            (current_rr.data_length));
                  Marshall (Buffer, Get_Element
                         (current_rr.rr_data.a_address, 1));
                  Marshall (Buffer, Get_Element
                         (current_rr.rr_data.a_address, 2));
                  Marshall (Buffer, Get_Element
                         (current_rr.rr_data.a_address, 3));
                  Marshall (Buffer, Get_Element
                         (current_rr.rr_data.a_address, 4));
               end if;
            when PTR =>
               Marshall (Buffer, PTR_Code);
               Marshall (Buffer, Default_Class_Code);
               if Is_Reply then
                  Marshall (Buffer, current_rr.TTL);
                  Marshall (Buffer, Types.Unsigned_Short
                   (current_rr.data_length));
                  Marshall_DNS_String (Buffer,
                   To_Standard_String (current_rr.rr_data.rr_answer));
               end if;
            when TXT =>
               Marshall (Buffer, TXT_Code);
               Marshall (Buffer, Default_Class_Code);
               if Is_Reply then
                  Marshall (Buffer, current_rr.TTL);
                  Marshall (Buffer, Types.Unsigned_Short
                   (current_rr.data_length));
                  Marshall_DNS_String (Buffer,
                   To_Standard_String (current_rr.rr_data.rr_answer));
               end if;
            when SRV =>
               Marshall (Buffer, SRV_Code);
               Marshall (Buffer, Default_Class_Code);
               if Is_Reply then
                  Marshall (Buffer, current_rr.TTL);
                  Marshall (Buffer, Types.Unsigned_Short
                            (current_rr.data_length));
                  Marshall (Buffer, current_rr.rr_data.srv_data.priority);
                  Marshall (Buffer, current_rr.rr_data.srv_data.weight);
                  Marshall (Buffer, current_rr.rr_data.srv_data.port);
                  Marshall_DNS_String (Buffer,
                   To_Standard_String (current_rr.rr_data.srv_data.target));
               end if;
            when others =>
               null;
         end case;
      end loop;
      pragma Debug (C, O ("Marshall_From_Any: leave"));
   end Marshall_From_Any;

   --  XXX : TODO : Move unmarshalling procedure here
   -----------------------
   -- Unmarshall_To_Any --
   -----------------------
--     procedure Unmarshall_To_Any
--       (Buffer : access Buffer_Type;
--       )
--     is
--        TC  : constant TypeCode.Object_Ptr :=
--                Unwind_Typedefs (Get_Type_Obj (CData));
--        TCK : constant TCKind := TypeCode.Kind (TC);
--     begin
--
--     end Unmarshall_To_Any;

      --  Marshalling of a Boolean

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : PolyORB.Types.Boolean)
   is
   begin
      pragma Debug (C, O ("Marshall (Boolean) : enter"));
      Marshall
        (Buffer, PolyORB.Types.Octet'(PolyORB.Types.Boolean'Pos (Data)));
      pragma Debug (C, O ("Marshall (Boolean) : end"));
   end Marshall;

   --  Marshalling of a Character

   procedure Marshall_Latin_1_Char
     (Buffer : access Buffer_Type;
      Data   : PolyORB.Types.Char)
   is
   begin
      pragma Debug (C, O ("Marshall (Char) : enter"));
      Marshall (Buffer, PolyORB.Types.Octet'(PolyORB.Types.Char'Pos (Data)));
      pragma Debug (C, O ("Marshall (Char) : end"));
   end Marshall_Latin_1_Char;

   function Unmarshall_Latin_1_Char
     (Buffer : access Buffer_Type) return PolyORB.Types.Char
   is
   begin
      pragma Debug (C, O ("Unmarshall (Char) : enter & end"));
      return PolyORB.Types.Char'Val
        (PolyORB.Types.Octet'(Unmarshall (Buffer)));
   end Unmarshall_Latin_1_Char;
   --  Marshalling of an Octet

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : PolyORB.Types.Octet)
   is
   begin
      pragma Debug (C, O ("Marshall (Octet) : enter"));
      Align_Marshall_Copy (Buffer, (1 => Stream_Element
                           (PolyORB.Types.Octet'(Data))), Align_1);
      pragma Debug (C, O ("Marshall (Octet) : end"));
   end Marshall;

   procedure Marshall_Latin_1_String
     (Buffer : access Buffer_Type;
      Data   : Standard.String)
   is
      Str : Stream_Element_Array (1 .. Data'Length);
      for Str'Address use Data'Address;
      pragma Import (Ada, Str);

   begin
      pragma Debug (C, O ("Marshall (String) : enter"));
      if Data'Length = 0 then
         return;
      end if;

      Marshall (Buffer, PolyORB.Types.Octet'(Data'Length));
      Align_Marshall_Copy (Buffer, Str);
      pragma Debug (C, O ("Marshall (String) : end"));
   end Marshall_Latin_1_String;

   --  Marshalling of a PolyORB.Types.String

   procedure Marshall_Latin_1_String
     (Buffer : access Buffer_Type;
      Data   : PolyORB.Types.String)
   is
   begin
      pragma Debug (C, O ("Marshall (PolyORB.Types.String) : enter"));
      Marshall_Latin_1_String
        (Buffer, PolyORB.Types.To_Standard_String (Data));
      pragma Debug (C, O ("Marshall (PolyORB.Types.String) : end"));
   end Marshall_Latin_1_String;

   procedure Marshall_DNS_String
     (Buffer : access Buffer_Type;
      Data   : Standard.String)
   is
      S       : String renames Data;
      Index   : Integer;
      Index2  : Integer;
      Label : PolyORB.Types.String;
   begin
      pragma Debug (C, O ("Marshall DNS string : enter"));
      Index := S'First;
      Index2 := Find (S, Index, '.');
      while Index2 > Index loop
         Label := To_PolyORB_String (S (Index .. Index2 - 1));
         Marshall_Latin_1_String (Buffer, Label);
         pragma Debug (C, O ("Marshall DNS string :label " &
           To_Standard_String (Label)));
         Index := Index2 + 1;
         Index2 := Find (S, Index, '.');
      end loop;
      Marshall (Buffer, Types.Octet (0));
      pragma Debug (C, O ("Marshall DNS string: end"));
   end Marshall_DNS_String;

   function Unmarshall_DNS_String
     (Buffer : access Buffer_Type)
      return PolyORB.Types.String
   is
      Length : PolyORB.Types.Octet
        := Unmarshall (Buffer);
      Label : Types.String := To_PolyORB_String ("");
   begin
      pragma Debug (C, O ("Unmarshall (String): enter"));
      pragma Debug (C, O ("Unmarshall (String): length is " &
                    PolyORB.Types.Octet'Image (Length)));
      if Length = 0 then
         pragma Debug (C, O ("Unmarshall (String): returning empty"));
         return To_PolyORB_String ("");
      end if;
      while Length /= Types.Octet (0) loop
         declare
            Equiv  : String (1 .. Natural (Length));
         begin
            for J in Equiv'Range loop
               Equiv (J) := Character'Val
                 (PolyORB.Types.Char'Pos (Unmarshall_Latin_1_Char (Buffer)));
            end loop;
            Label := Label & To_PolyORB_String (Equiv);
            pragma Debug (C, O ("Unmarshall DNS (String): -> " &
              To_Standard_String (Label)));
         end;
         Length := Unmarshall (Buffer);
         pragma Debug (C, O ("Unmarshall (String): length is " &
             PolyORB.Types.Octet'Image (Length)));
         if Length /= Types.Octet (0) then
            Label := Label & ".";
         end if;
      end loop;
      pragma Debug (C, O ("Unmarshall (String): -> " &
        To_Standard_String (Label)));
      return Label;
   end Unmarshall_DNS_String;

   function Unmarshall_Latin_1_String
     (Buffer : access Buffer_Type)
     return Standard.String
   is
      Length : constant PolyORB.Types.Unsigned_Short
        := Unmarshall (Buffer);
      Equiv  : String (1 .. Natural (Length) - 1);

   begin
      pragma Debug (C, O ("Unmarshall (String): enter"));
      pragma Debug (C, O ("Unmarshall (String): length is " &
                    PolyORB.Types.Unsigned_Short'Image (Length)));

      if Length = 0 then
         return "";
      end if;

      for J in Equiv'Range loop
         Equiv (J) := Character'Val
           (PolyORB.Types.Char'Pos (Unmarshall_Latin_1_Char (Buffer)));
      end loop;

      if Character'Val
           (PolyORB.Types.Char'Pos (Unmarshall_Latin_1_Char (Buffer)))
        /= ASCII.NUL
      then
         raise Constraint_Error;
      end if;

      pragma Debug (C, O ("Unmarshall (String): -> " & Equiv));

      return Equiv;
   end Unmarshall_Latin_1_String;

   ------------------------------------
   -- Unmarshall-by-copy subprograms --
   ------------------------------------

   function Unmarshall
     (Buffer : access Buffer_Type) return PolyORB.Types.Boolean
   is
   begin
      pragma Debug (C, O ("Unmarshall (Boolean) : enter & end"));
      return PolyORB.Types.Boolean'Val
        (PolyORB.Types.Octet'(Unmarshall (Buffer)));
   end Unmarshall;

   function Swapped (X : Types.Octet) return Types.Octet;
   pragma Inline (Swapped);
   package DNS_Octet is
     new Align_Transfer_Elementary (T => PolyORB.Types.Octet);
   function Unmarshall
     (Buffer : access Buffer_Type) return PolyORB.Types.Octet
      renames DNS_Octet.Unmarshall;
   function Swapped (X : Types.Octet) return Types.Octet is
   begin
      return X;
   end Swapped;

   function Swapped is
     new GNAT.Byte_Swapping.Swapped4 (PolyORB.Types.Unsigned_Long);
   package DNS_Unsigned_Long is
     new Align_Transfer_Elementary (T => PolyORB.Types.Unsigned_Long,
                                    With_Alignment => False);
   function Unmarshall
     (Buffer : access Buffer_Type) return PolyORB.Types.Unsigned_Long
      renames DNS_Unsigned_Long.Unmarshall;

   procedure Marshall
     (Buffer : access Buffer_Type; Data : PolyORB.Types.Unsigned_Long)
      renames DNS_Unsigned_Long.Marshall;

   function Swapped is
     new GNAT.Byte_Swapping.Swapped2 (PolyORB.Types.Unsigned_Short);
   package DNS_Unsigned_Short is
     new Align_Transfer_Elementary (T => PolyORB.Types.Unsigned_Short,
                                    With_Alignment => False);
   procedure Marshall
     (Buffer : access Buffer_Type; Data : PolyORB.Types.Unsigned_Short)
      renames DNS_Unsigned_Short.Marshall;

   function Unmarshall
     (Buffer : access Buffer_Type) return PolyORB.Types.Unsigned_Short
      renames DNS_Unsigned_Short.Unmarshall;

   procedure Initialize;
   procedure Initialize is
   begin
      null;
   end Initialize;

   use PolyORB.Initialization;
   use PolyORB.Initialization.String_Lists;
   use PolyORB.Utils.Strings;

begin
   Register_Module
     (Module_Info'
      (Name      => +"representations.dns",
       Conflicts => Empty,
       Depends   => Empty,
       Provides  => Empty,
       Implicit  => False,
       Init      => Initialize'Access,
       Shutdown  => null));
end PolyORB.Representations.DNS;
