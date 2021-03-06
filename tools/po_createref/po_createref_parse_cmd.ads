------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--               P O _ C R E A T E R E F _ P A R S E _ C M D                --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--         Copyright (C) 2007-2017, Free Software Foundation, Inc.          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.                                               --
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

with GNAT.OS_Lib; use GNAT.OS_Lib;
with PolyORB.Types;

package PO_CreateRef_Parse_Cmd is

   type Parameter_Address is record
      Inet_Addr      : String_Access;
      Port           : Positive;
   end record;
   --  ??? Should use PolyORB.Sockets.Socket_Name instead!

   type Policy_Subcomponent is record
      Priority_Model     : String_Access;
      Priority_Value     : Positive;
   end record;

   type Policies_Array is array (Natural range <>)
     of Policy_Subcomponent;
   type Policies_Array_Access is access Policies_Array;

   type Codeset_Array is array (Natural range <>)
     of String_Access;
   type Codeset_Array_Access is access Codeset_Array;

   type Parameter_Component is record
      C_Type         : String_Access;

      --  Policies component
      Policies       : Policies_Array_Access;

      --  Code_Set component
      Cchar          : String_Access;
      C_Supported    : Codeset_Array_Access;
      Wchar          : String_Access;
      W_Supported    : Codeset_Array_Access;

      --  SSL
      SSL_Supports   : String_Access;
      SSL_Requires   : String_Access;

      --  alternate iiop address
      Address        : Parameter_Address;
   end record;

   type Component_Array is array (Natural range <>)
     of Parameter_Component;
   type Ptr_Components is access Component_Array;

   type Parameter_Profile is record
      Profile_Type   : String_Access;
      Index          : String_Access;
      Is_Generated   : Boolean := False;
      Creator_Name   : String_Access;
      Version_Major  : PolyORB.Types.Octet;
      Version_Minor  : PolyORB.Types.Octet;
      Address        : Parameter_Address;
      Components     : Ptr_Components;
   end record;

   type Profiles_Array is array (Natural range <>) of Parameter_Profile;
   type Ptr_Profiles is access Profiles_Array;

   type Parameter_Ref is record
      Ref_Type       : String_Access;
      Profiles       : Ptr_Profiles;
   end record;

   procedure Parse_Command_Line (Param : out Parameter_Ref);

   procedure Free (Ptr : in out Parameter_Ref);

end PO_CreateRef_Parse_Cmd;
