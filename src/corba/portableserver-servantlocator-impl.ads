------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--   P O R T A B L E S E R V E R . S E R V A N T L O C A T O R . I M P L    --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--         Copyright (C) 2005-2012, Free Software Foundation, Inc.          --
--                                                                          --
-- This specification is derived from the CORBA Specification, and adapted  --
-- for use with PolyORB. The copyright notice above, and the license        --
-- provisions that follow apply solely to the contents neither explicitly   --
-- nor implicitly specified by the CORBA Specification defined by the OMG.  --
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

pragma Ada_2012;

with PortableServer.ServantManager.Impl;

package PortableServer.ServantLocator.Impl is

   type Object is new PortableServer.ServantManager.Impl.Object with private;

   type Object_Ptr is access all Object'Class;

   procedure Preinvoke
     (Self       : access Object;
      Oid        :        PortableServer.ObjectId;
      Adapter    :        PortableServer.POA_Forward.Ref;
      Operation  :        CORBA.Identifier;
      The_Cookie :    out PortableServer.ServantLocator.Cookie;
      Returns    :    out PortableServer.Servant);

   procedure Postinvoke
     (Self        : access Object;
      Oid         :        PortableServer.ObjectId;
      Adapter     :        PortableServer.POA_Forward.Ref;
      Operation   :        CORBA.Identifier;
      The_Cookie  :        PortableServer.ServantLocator.Cookie;
      The_Servant :        PortableServer.Servant);

private

   type Object is
     new PortableServer.ServantManager.Impl.Object with null record;

   overriding function Is_A
     (Self            : not null access Object;
      Logical_Type_Id : Standard.String) return Boolean;

end PortableServer.ServantLocator.Impl;
