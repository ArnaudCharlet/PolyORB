------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                           C O R B A . I M P L                            --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2001-2003 Free Software Foundation, Inc.           --
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
--                PolyORB is maintained by ACT Europe.                      --
--                    (email: sales@act-europe.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

--  $Id$

package body CORBA.Impl is

   ---------------------
   -- Execute_Servant --
   ---------------------

   function Execute_Servant
     (Self : access Object;
      Msg  :        PolyORB.Components.Message'Class)
     return PolyORB.Components.Message'Class
   is
      use PolyORB.Components;

      Res : Null_Message;
   begin
      raise Unhandled_Message;
      return Res;
   end Execute_Servant;

   function Execute_Servant
     (Self : access Implementation;
      Msg  :        PolyORB.Components.Message'Class)
     return PolyORB.Components.Message'Class is
   begin
      return Execute_Servant (Self.As_Object, Msg);
   end Execute_Servant;

   ------------------------
   -- To_PolyORB_Servant --
   ------------------------

   function To_PolyORB_Servant
     (S : access Object)
     return PolyORB.Servants.Servant_Access is
   begin
      return S.Neutral_View'Access;
   end To_PolyORB_Servant;

   ----------------------
   -- To_CORBA_Servant --
   ----------------------

   function To_CORBA_Servant
     (S : PolyORB.Servants.Servant_Access)
     return Object_Ptr
   is
      use type PolyORB.Servants.Servant_Access;

   begin
      if S = null then
         return null;
      else
         return Object_Ptr (Implementation (S.all).As_Object);
      end if;
   end To_CORBA_Servant;

   ---------
   -- "=" --
   ---------

   function "="
     (X, Y : Implementation)
     return Boolean is
   begin
      raise Program_Error;
      return False;
   end "=";

end CORBA.Impl;