------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--               POLYORB.POA_POLICIES.THREAD_POLICY.ORB_CTRL                --
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

--  $Id$

package body PolyORB.POA_Policies.Thread_Policy.ORB_Ctrl is

   ------------
   -- Create --
   ------------

   function Create return ORB_Ctrl_Policy_Access is
   begin
      return new ORB_Ctrl_Policy;
   end Create;

   ---------------
   -- Policy_Id --
   ---------------

   function Policy_Id
     (Self : ORB_Ctrl_Policy)
     return String is
   begin
      return "THREAD_POLICY.ORB_CTRL";
   end Policy_Id;

   -------------------------
   -- Check_Compatibility --
   -------------------------

   procedure Check_Compatibility
     (Self : ORB_Ctrl_Policy;
      OA   : PolyORB.POA_Types.Obj_Adapter_Access)
   is
   begin
      null;
   end Check_Compatibility;

   ----------
   -- Free --
   ----------

   procedure Free
     (P   : in     ORB_Ctrl_Policy;
      Ptr : in out Policy_Access)
   is
   begin
      Free (ORB_Ctrl_Policy_Access (Ptr));
   end Free;

end PolyORB.POA_Policies.Thread_Policy.ORB_Ctrl;
