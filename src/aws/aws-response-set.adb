------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                     A W S . R E S P O N S E . S E T                      --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2002-2012, Free Software Foundation, Inc.          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.                                               --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

with AWS.Translator;
with AWS.Headers.Set;
with AWS.Digest;

package body AWS.Response.Set is

--   procedure Update_Data_From_Header (D : in out Data);
   --  Update some Data fields from the internal Data header container.
   --  The Update_Data_From_Header should be called after the complete
   --  header parsing.

   ----------------
   -- Add_Header --
   ----------------

   procedure Add_Header
     (D     : in out Data;
      Name  : String;
      Value : String) is
   begin
      Headers.Set.Add (D.Header, Name, Value);
   end Add_Header;

   --------------------
   -- Authentication --
   --------------------

   procedure Authentication
     (D     : in out Data;
      Realm : String;
      Mode  : Authentication_Mode := Basic;
      Stale : Boolean             := False)
   is
      N : Positive := 1;
      --  The index for the update of WWW-Authenticate header values.
      --  We are not using AWS.Headers.Set.Add routine for add WWW-Authenticate
      --  header lines, becouse user could call this routine more than once.
   begin

      --  In case of Authenticate = Any
      --  We should create both header lines
      --  WWW-Authenticate: Basic
      --  and
      --  WWW-Authenticate: Digest

      if Mode = Digest or Mode = Any then
         Headers.Set.Update
           (D.Header,
            Name  => Messages.WWW_Authenticate_Token,
            Value => "Digest qop=""auth"", realm=""" & Realm
                     & """, stale=""" & Boolean'Image (Stale)
                     & """, nonce=""" & AWS.Digest.Create_Nonce & """",
            N => N);
         N := N + 1;
      end if;

      if Mode = Basic or Mode = Any then
         Headers.Set.Update
           (D.Header,
            Name  => Messages.WWW_Authenticate_Token,
            Value => "Basic realm=""" & Realm & """",
            N     => N);
      end if;

      D.Status_Code    := Messages.S401;
   end Authentication;

   -------------------
   -- Cache_Control --
   -------------------

   procedure Cache_Control
     (D     : in out Data;
      Value : Messages.Cache_Option) is
   begin
      Headers.Set.Update
        (D.Header,
         Name  => Messages.Cache_Control_Token,
         Value => String (Value));
   end Cache_Control;

   --------------------
   -- Content_Length --
   --------------------

   procedure Content_Length
     (D     : in out Data;
      Value : Natural) is
   begin
      D.Content_Length := Value;
   end Content_Length;

   ------------------
   -- Content_Type --
   ------------------

   procedure Content_Type
     (D     : in out Data;
      Value : String) is
   begin
      Headers.Set.Update
        (D.Header,
         Name  => Messages.Content_Type_Token,
         Value => Value);
   end Content_Type;

   --------------
   -- Filename --
   --------------

   procedure Filename
     (D     : in out Data;
      Value : String) is
   begin
      D.Filename       := To_Unbounded_String (Value);
      D.Mode           := File;
      D.Content_Length := Integer (Resources.File_Size (Value));
   end Filename;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (D : Data) return Boolean is
      use type Messages.Status_Code;
      Redirection_Code : Boolean;
   begin
      case D.Status_Code is
         when
           Messages.S300 | -- Section 10.3.1: Multiple Choices
           Messages.S301 | -- Section 10.3.2: Moved Permanently
           Messages.S302 | -- Section 10.3.3: Found
           Messages.S303 | -- Section 10.3.4: See Other
           Messages.S305 | -- Section 10.3.6: Use Proxy
           Messages.S307   -- Section 10.3.8: Temporary Redirect
           =>
            Redirection_Code := True;

         when others =>
            Redirection_Code := False;
      end case;

      return (Redirection_Code
                xor not Headers.Exist
                          (D.Header,
                           Messages.Location_Token))
        and then (D.Status_Code = Messages.S401
                    xor not Headers.Exist
                              (D.Header,
                               Messages.WWW_Authenticate_Token));
   end Is_Valid;

   --------------
   -- Location --
   --------------

   procedure Location
     (D     : in out Data;
      Value : String) is
   begin
      Headers.Set.Update
        (D.Header,
         Name  => Messages.Location_Token,
         Value => Value);
   end Location;

   ------------------
   -- Message_Body --
   ------------------

   procedure Message_Body
     (D     : in out Data;
      Value : Streams.Stream_Element_Array) is
   begin
      Utils.Free (D.Message_Body);
      D.Message_Body   := new Streams.Stream_Element_Array'(Value);
      D.Content_Length := Value'Length;
      D.Mode           := Message;
   end Message_Body;

   procedure Message_Body
     (D     : in out Data;
      Value : Utils.Stream_Element_Array_Access) is
   begin
      Utils.Free (D.Message_Body);
      D.Message_Body   := Value;
      D.Content_Length := Value'Length;
      D.Mode           := Message;
   end Message_Body;

   procedure Message_Body
     (D     : in out Data;
      Value : String) is
   begin
      Message_Body (D, Translator.To_Stream_Element_Array (Value));
   end Message_Body;

   procedure Message_Body
     (D     : in out Data;
      Value : Strings.Unbounded.Unbounded_String) is
   begin
      Message_Body (D, To_String (Value));
   end Message_Body;

   procedure Message_Body
     (D     : in out Data;
      Value : SOAP.Message.Response.Object) is
   begin
      D.SOAP_Message := SOAP.Message.Response.Object'(Value);
      D.Mode := SOAP_Message;
   end Message_Body;

   ----------
   -- Mode --
   ----------

   procedure Mode
     (D     : in out Data;
      Value : Data_Mode) is
   begin
      D.Mode := Value;
   end Mode;

   -----------------
   -- Read_Header --
   -----------------

--     procedure Read_Header
--       (Socket : Net.Socket_Type'Class;
--        D      : in out Data) is
--     begin
--        pragma Warnings (Off);
--        pragma Unreferenced (Socket);
--        pragma Warnings (On);
--      Headers.Set.Read (Socket, D.Header);
--        Update_Data_From_Header (D);
--     end Read_Header;

   -----------------
   -- Status_Code --
   -----------------

   procedure Status_Code
     (D     : in out Data;
      Value : Messages.Status_Code) is
   begin
      D.Status_Code := Value;
   end Status_Code;

   ------------
   -- Stream --
   ------------

   procedure Stream
     (D              : in out Data;
      Handle         : Resources.Streams.Stream_Access;
      Content_Length : Content_Length_Type) is
   begin
      D.Stream         := Handle;
      D.Content_Length := Content_Length;
      D.Mode           := Stream;
   end Stream;

   -----------------------------
   -- Update_Data_From_Header --
   -----------------------------

--     procedure Update_Data_From_Header (D : in out Data) is
--        Content_Length_Image : constant String
--          := Headers.Get (D.Header, Messages.Content_Length_Token);
--     begin
--        if Content_Length_Image = "" then
--           D.Content_Length := Undefined_Length;
--        else
--       D.Content_Length := Content_Length_Type'Value (Content_Length_Image);
--        end if;
--     end Update_Data_From_Header;

   -------------------
   -- Update_Header --
   -------------------

   procedure Update_Header
     (D     : in out Data;
      Name  : String;
      Value : String;
      N     : Positive := 1) is
   begin
      Headers.Set.Update (D.Header, Name, Value, N);
   end Update_Header;

end AWS.Response.Set;
