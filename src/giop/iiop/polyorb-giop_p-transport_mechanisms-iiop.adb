------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                POLYORB.GIOP_P.TRANSPORT_MECHANISMS.IIOP                  --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2005-2017, Free Software Foundation, Inc.          --
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

with PolyORB.Binding_Data.GIOP.IIOP;
with PolyORB.Binding_Objects;
with PolyORB.Filters.Slicers;
with PolyORB.GIOP_P.Tagged_Components.Alternate_IIOP_Address;
with PolyORB.Initialization;
with PolyORB.ORB;
with PolyORB.Protocols.GIOP.IIOP;
with PolyORB.Sockets;
with PolyORB.Transport.Connected.Sockets;
with PolyORB.Utils.Strings;

package body PolyORB.GIOP_P.Transport_Mechanisms.IIOP is

   use PolyORB.Errors;
   use PolyORB.GIOP_P.Tagged_Components;
   use PolyORB.GIOP_P.Tagged_Components.Alternate_IIOP_Address;
   use PolyORB.Sockets;
   use PolyORB.Transport.Connected.Sockets;
   use Socket_Name_Lists;

   procedure Initialize;

   procedure Create
     (TC      : Tagged_Components.Tagged_Component_Access;
      Profile : Binding_Data.Profile_Access;
      Mechs   : in out Transport_Mechanism_List);
   --  Create list of Transport Mechanism from list of Tagged Component

   --------------------
   -- Bind_Mechanism --
   --------------------

   --  Factories

   Sli            : aliased PolyORB.Filters.Slicers.Slicer_Factory;
   Pro            : aliased PolyORB.Protocols.GIOP.IIOP.IIOP_Protocol;
   IIOP_Factories : constant PolyORB.Filters.Factory_Array :=
     (0 => Sli'Access, 1 => Pro'Access);

   overriding procedure Bind_Mechanism
     (Mechanism : IIOP_Transport_Mechanism;
      Profile   : access PolyORB.Binding_Data.Profile_Type'Class;
      The_ORB   : Components.Component_Access;
      QoS       : PolyORB.QoS.QoS_Parameters;
      BO_Ref    : out Smart_Pointers.Ref;
      Error     : out Errors.Error_Container)
   is
      pragma Unreferenced (QoS);

      use PolyORB.Binding_Data;

      Iter : Socket_Name_Lists.Iterator := First (Mechanism.Addresses);

   begin
      if Profile.all
        not in PolyORB.Binding_Data.GIOP.IIOP.IIOP_Profile_Type
      then
         Throw (Error, Comm_Failure_E,
                System_Exception_Members'
                (Minor => 0, Completed => Completed_Maybe));
         return;
      end if;

      while not Last (Iter) loop
         declare
            Sock        : Socket_Type;
            Remote_Addr : Socket_Name renames Value (Iter).all.all;
            TE          : constant Transport.Transport_Endpoint_Access :=
              new Socket_Endpoint;

         begin
            Utils.Sockets.Create_Socket (Sock);
            Utils.Sockets.Connect_Socket (Sock, Remote_Addr);
            Create (Socket_Endpoint (TE.all), Sock);

            Binding_Objects.Setup_Binding_Object
              (The_ORB,
               TE,
               IIOP_Factories,
               BO_Ref,
               Profile_Access (Profile));

            ORB.Register_Binding_Object
              (ORB.ORB_Access (The_ORB),
               BO_Ref,
               ORB.Client);

            return;

         exception
            when Sockets.Socket_Error =>
               Throw (Error, Comm_Failure_E,
                      System_Exception_Members'
                      (Minor => 0, Completed => Completed_No));
         end;

         Next (Iter);

         if not Last (Iter) and then Found (Error) then
            Catch (Error);
         end if;
      end loop;
   end Bind_Mechanism;

   ------------
   -- Create --
   ------------

   procedure Create
     (TC      : Tagged_Components.Tagged_Component_Access;
      Profile : Binding_Data.Profile_Access;
      Mechs   : in out Transport_Mechanism_List)
   is
      pragma Unreferenced (Mechs);
      --  Behaviour is not conformant with spec, we add the additional address
      --  from TC directly into the primary transport mechanism, instead of
      --  creating a separate mechanism???

      use PolyORB.Binding_Data.GIOP;

      Mechanism : constant Transport_Mechanism_Access :=
        Get_Primary_Transport_Mechanism (GIOP_Profile_Type (Profile.all));

   begin
      Append
        (IIOP_Transport_Mechanism (Mechanism.all).Addresses,
         new Socket_Name'(TC_Alternate_IIOP_Address (TC.all).Address.all));
   end Create;

   --------------------
   -- Create_Factory --
   --------------------

   overriding procedure Create_Factory
     (MF  : out IIOP_Transport_Mechanism_Factory;
      TAP : access Transport.Transport_Access_Point'Class)
   is
   begin
      Append
        (MF.Addresses,
         new Socket_Name'
           (Connected_Socket_AP (TAP.all).Socket_AP_Publish_Name));
   end Create_Factory;

   ------------------------------
   -- Create_Tagged_Components --
   ------------------------------

   overriding function Create_Tagged_Components
     (MF : IIOP_Transport_Mechanism_Factory)
      return Tagged_Components.Tagged_Component_List
   is
      Result : Tagged_Component_List;

      Iter : Iterator := First (MF.Addresses);

   begin
      --  If Transport Mechanism is disabled (e.g. unprotected invocation
      --  has been disabled), then don't create any tagged components for
      --  alternative addresses.

      if MF.Disabled then
         return Result;
      end if;

      Next (Iter);
      --  Skipping first address in the list because it is a primary address,
      --  declared in profile itself.

      while not Last (Iter) loop
         declare
            TC : constant Tagged_Component_Access :=
              new TC_Alternate_IIOP_Address;
         begin
            TC_Alternate_IIOP_Address (TC.all).Address :=
              new Socket_Name'(Value (Iter).all.all);
            Add (Result, TC);
         end;

         Next (Iter);
      end loop;

      return Result;
   end Create_Tagged_Components;

   --------------------------------
   -- Create_Transport_Mechanism --
   --------------------------------

   function Create_Transport_Mechanism
     (MF : IIOP_Transport_Mechanism_Factory)
      return Transport_Mechanism_Access
   is
      Result  : constant Transport_Mechanism_Access :=
        new IIOP_Transport_Mechanism;
      TResult : IIOP_Transport_Mechanism
        renames IIOP_Transport_Mechanism (Result.all);
      Iter    : Iterator := First (MF.Addresses);

   begin
      --  If Transport Mechanism is disabled (e.g. unprotected invocation
      --  has been disabled), add only primary address with zero port number
      --  and ignore all alternate addresses. Otherwise, add all addresses.

      while not Last (Iter) loop
         declare
            Addr : Socket_Name := Value (Iter).all.all;
         begin
            if MF.Disabled then
               Addr.Port := 0;
            end if;
            Append (TResult.Addresses, new Socket_Name'(Addr));
         end;

         --  In the disabled case, we just set the first address

         exit when MF.Disabled;
         Next (Iter);
      end loop;
      return Result;
   end Create_Transport_Mechanism;

   function Create_Transport_Mechanism
     (Address : Utils.Sockets.Socket_Name)
      return Transport_Mechanism_Access
   is
      Result  : constant Transport_Mechanism_Access :=
        new IIOP_Transport_Mechanism;
      TResult : IIOP_Transport_Mechanism
        renames IIOP_Transport_Mechanism (Result.all);

   begin
      Append (TResult.Addresses, new Socket_Name'(Address));
      return Result;
   end Create_Transport_Mechanism;

   ---------------------------------
   -- Disable_Transport_Mechanism --
   ---------------------------------

   procedure Disable_Transport_Mechanism
     (MF : in out IIOP_Transport_Mechanism_Factory)
   is
   begin
      MF.Disabled := True;
   end Disable_Transport_Mechanism;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Register (Tag_Alternate_IIOP_Address, Create'Access);
   end Initialize;

   ------------------------
   -- Is_Local_Mechanism --
   ------------------------

   overriding function Is_Local_Mechanism
     (MF : access IIOP_Transport_Mechanism_Factory;
      M  : access Transport_Mechanism'Class)
      return Boolean
   is
      Iter_1 : Iterator;

   begin
      if MF.Disabled
        or else M.all not in IIOP_Transport_Mechanism
      then
         return False;
      end if;

      Iter_1 := First (IIOP_Transport_Mechanism (M.all).Addresses);

      if M.all in IIOP_Transport_Mechanism then
         while not Last (Iter_1) loop
            declare
               Iter_2 : Iterator := First (MF.Addresses);

            begin
               while not Last (Iter_2) loop
                  if Value (Iter_1).all.all = Value (Iter_2).all.all then
                     return True;
                  end if;

                  Next (Iter_2);
               end loop;
            end;

            Next (Iter_1);
         end loop;
      end if;

      return False;
   end Is_Local_Mechanism;

   ------------------------
   -- Primary_Address_Of --
   ------------------------

   function Primary_Address_Of
     (M : IIOP_Transport_Mechanism) return Utils.Sockets.Socket_Name
   is
   begin
      return Element (M.Addresses, 0).all.all;
   end Primary_Address_Of;

   ----------------------
   -- Release_Contents --
   ----------------------

   overriding procedure Release_Contents
     (M : access IIOP_Transport_Mechanism)
   is
      Iter : Socket_Name_Lists.Iterator := First (M.Addresses);
   begin
      while not Last (Iter) loop
         Free (Value (Iter).all);
         Next (Iter);
      end loop;
      Deallocate (M.Addresses);
   end Release_Contents;

   ---------------
   -- Duplicate --
   ---------------

   overriding function Duplicate
     (TMA : IIOP_Transport_Mechanism)
     return IIOP_Transport_Mechanism
   is
      Iter : Socket_Name_Lists.Iterator := First (TMA.Addresses);
      Result : IIOP_Transport_Mechanism;
   begin
      while not Last (Iter) loop
         Append (Result.Addresses, new Socket_Name'(Value (Iter).all.all));
         Next (Iter);
      end loop;
      return Result;
   end Duplicate;

   ------------------
   -- Is_Colocated --
   ------------------

   overriding function Is_Colocated
     (Left  : IIOP_Transport_Mechanism;
      Right : Transport_Mechanism'Class) return Boolean
   is
   begin
      if Right not in IIOP_Transport_Mechanism then
         return False;
      end if;

      declare
         L_Iter : Iterator := First (Left.Addresses);
         R_Iter : Iterator;
      begin

         --  Check if Left.Addresses and Right.Addresses have an address in
         --  common.

         Left_Addresses :
         while not Last (L_Iter) loop

            R_Iter := First (IIOP_Transport_Mechanism (Right).Addresses);

            Right_Addresses :
            while not Last (R_Iter) loop
               if Value (L_Iter).all.all = Value (R_Iter).all.all then
                  return True;
               end if;
               Next (R_Iter);
            end loop Right_Addresses;

            Next (L_Iter);
         end loop Left_Addresses;
      end;

      return False;
   end Is_Colocated;

begin
   declare
      use PolyORB.Initialization;
      use PolyORB.Utils.Strings;

   begin
      Register_Module
        (Module_Info'
         (Name      => +"giop_p.transport_mechanisms.iiop",
          Conflicts => PolyORB.Initialization.String_Lists.Empty,
          Depends   => PolyORB.Initialization.String_Lists.Empty,
          Provides  => PolyORB.Initialization.String_Lists.Empty,
          Implicit  => False,
          Init      => Initialize'Access,
          Shutdown  => null));
   end;
end PolyORB.GIOP_P.Transport_Mechanisms.IIOP;
