------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                  A D A _ B E . M A P P I N G S . D S A                   --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--         Copyright (C) 1999-2012, Free Software Foundation, Inc.          --
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

--  The DSA personality IDL mapping.

package Ada_Be.Mappings.DSA is

   pragma Elaborate_Body;

   type DSA_Mapping_Type is new Mapping_Type with private;

   function Library_Unit_Name
     (Self : access DSA_Mapping_Type;
      Node : Idl_Fe.Types.Node_Id)
     return String;

   function Client_Stubs_Unit_Name
     (Self : access DSA_Mapping_Type;
      Node : Idl_Fe.Types.Node_Id)
     return String;

   function Server_Skel_Unit_Name
     (Self : access DSA_Mapping_Type;
      Node : Idl_Fe.Types.Node_Id)
     return String;

   function Self_For_Operation
     (Self : access DSA_Mapping_Type;
      Node : Idl_Fe.Types.Node_Id)
     return String;

   procedure Map_Type_Name
     (Self : access DSA_Mapping_Type;
      Node : Idl_Fe.Types.Node_Id;
      Unit : out ASU.Unbounded_String;
      Typ  : out ASU.Unbounded_String);

   function Calling_Stubs_Type
     (Self : access DSA_Mapping_Type;
      Node : Idl_Fe.Types.Node_Id)
     return String;

   function Generate_Scope_In_Child_Package
     (Self : access DSA_Mapping_Type;
      Node : Idl_Fe.Types.Node_Id)
     return Boolean;

   The_DSA_Mapping : constant DSA_Mapping_Type;

private

   type DSA_Mapping_Type is new Mapping_Type with null record;

   The_DSA_Mapping : constant DSA_Mapping_Type
     := (Mapping_Type with null record);

end Ada_Be.Mappings.DSA;
