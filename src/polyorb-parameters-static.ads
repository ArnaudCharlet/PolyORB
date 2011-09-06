------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--            P O L Y O R B . P A R A M E T E R S . S T A T I C             --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--         Copyright (C) 2008-2011, Free Software Foundation, Inc.          --
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

package PolyORB.Parameters.Static is

   pragma Elaborate_Body;

   type Parameter_Ptr is access constant Standard.String;
   type Value_Ptr     is access constant Standard.String;

   type Parameter_Entry is record
      Parameter : Parameter_Ptr;
      Value     : Value_Ptr;
   end record;

   --  Static array of parameters for link-time configuration of PolyORB

   --  Requirements:
   --  - The last entry must be equal to Last_Entry: (null, null)
   --  - The application must export an array of the following type with
   --    Static_Parameters_Link_Name as the external name.

   --  See PolyORB's User Manual section 4.2 [Run-time configuration] for
   --  further information.

   type Static_Parameter_Array is
     array (Positive range <>) of Parameter_Entry;

   Static_Parameters_Link_Name : constant String :=
                                   "__PolyORB_static_parameters";
   Last_Entry : constant Parameter_Entry := (null, null);

end PolyORB.Parameters.Static;
