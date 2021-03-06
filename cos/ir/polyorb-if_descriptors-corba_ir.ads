------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--      P O L Y O R B . I F _ D E S C R I P T O R S . C O R B A _ I R       --
--                                                                          --
--                                 S p e c                                  --
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

--  An Interface Descriptor that uses the CORBA Interface Repository.

package PolyORB.If_Descriptors.CORBA_IR is

   type IR_If_Descriptor is new If_Descriptor with private;

   function Get_Empty_Arg_List
     (If_Desc : access IR_If_Descriptor;
      Object  :        PolyORB.References.Ref;
      Method  :        String)
     return Any.NVList.Ref;

   function Get_Empty_Result
     (If_Desc : access IR_If_Descriptor;
      Object  :        PolyORB.References.Ref;
      Method  :        String)
     return Any.Any;

private

   type IR_If_Descriptor is new If_Descriptor
     with null record;

end PolyORB.If_Descriptors.CORBA_IR;
