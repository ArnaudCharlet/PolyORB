------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                     P O L Y O R B . R E Q U E S T S                      --
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

--  The Request object.

--  $Id$

with PolyORB.Log;
pragma Elaborate_All (PolyORB.Log);
with PolyORB.ORB;
with PolyORB.ORB.Interface;
with PolyORB.Protocols.Interface;
with PolyORB.Setup;

package body PolyORB.Requests is

   use PolyORB.Log;
   use PolyORB.Types;

   package L is new PolyORB.Log.Facility_Log ("polyorb.requests");
   procedure O (Message : in String; Level : Log_Level := Debug)
     renames L.Output;

   procedure Create_Request
     (Target    : in     References.Ref;
      --  May or may not be local!
      --  Ctx       : in     Any.Context.Ref;
      Operation : in     Operation_Id;
      Arg_List  : in     Any.NVList.Ref;
      Result    : in out Any.NamedValue;
      --  Exc_List  : in     ExceptionList.Ref;
      --  Ctxt_List : in     ContextList.Ref;
      Req       :    out Request_Access;
      --  Req_Flags : in     Flags
      Deferred_Arguments_Session : in Components.Component_Access := null
     )
   is
      Res : constant Request_Access := new Request;
      Result_Any : PolyORB.Any.Any := Any.Get_By_Ref (Result.Argument);
   begin
      Res.Target    := Target;
      Res.Operation := To_PolyORB_String (Operation);
      Res.Args      := Arg_List;
      Res.Deferred_Arguments_Session := Deferred_Arguments_Session;
      Res.Result    :=
        (Name      => Result.Name,
         Argument  => Result_Any,
         Arg_Modes => Result.Arg_Modes);

      Req := Res;
   end Create_Request;

   procedure Invoke (Self : Request_Access)
   is
      use PolyORB.ORB;
      use PolyORB.ORB.Interface;
      use PolyORB.Setup;

   begin
      PolyORB.ORB.Queue_Request_To_Handler
        (The_ORB.Tasking_Policy, The_ORB,
         Queue_Request'
         (Request   => Self,
          Requestor => null));
      --  XXX Only synchronous requests are supported!

      --  Execute the ORB until the request is completed.
      ORB.Run
        (The_ORB, Exit_Condition_T'
         (Condition => Self.Completed'Access,
          Task_Info => Self.Requesting_Task'Access),
         May_Poll => True);

   end Invoke;

   procedure Pump_Up_Arguments
     (A_Args : in out Any.NVList.Ref;
      P_Args : Any.NVList.Ref;
      Direction : Any.Flags)
   is
      use PolyORB.Components;

      use PolyORB.Any;
      use PolyORB.Any.NVList;
      use PolyORB.Any.NVList.Internals;
      use PolyORB.Any.NVList.Internals.NV_Sequence;

      P_Arg_Index : Integer := 1;
      --  Index in Self.Args (protocol layer arguments)
   begin
      pragma Assert (Direction = ARG_IN or else Direction = ARG_OUT);

      --  When Direction is ARG_IN, we are a server and we
      --  are pumping arguments from an incoming request message
      --  into the request that will be processed by the
      --  actual application object. In this case, we know
      --  that arguments in A_Args have their correct canonical
      --  modes and names. We assume that P_Args only contain
      --  arguments whose actual mode (as specifid in A_Args) is
      --  ARG_IN or ARG_INOUT, possibly without names. If without
      --  names, we assume that they are in the order of A_Args.

      --  When direction is ARG_OUT, we are a client and
      --  we are pumping up INOUT and OUT arguments from an
      --  incoming reply message into the request that will be
      --  handed back to the client appplication object.
      --  (no return value must be present in P_Args, only
      --  actual arguments). We assue that P_Args only contain
      --  arguments whose actual mode is ARG_INOUT or ARG_OUT,
      --  possibly without names, and if without names in the
      --  order of A_Args.

      --  Note that we cannot rely on the mode indications in
      --  P_Args because some protocols (eg SOAP) do not
      --  set it correcly (more specifically SOAP does not support
      --  deferred unmarshalling, and insist on unmarshalling Self.Args
      --  before Arguments is called. Consequence: 'OUT' mode arguments
      --  might be missing in Self.Args, and 'INOUT' arguments might
      --  be marked as 'IN'. Also, there is no guarantee that the order
      --  of arguments is the same in Args and Self.Args.)

      --  XXX actually for now we do not check names at all:
      --  we skip P_Args with the wrong direction and then assume
      --  strict positional association.
      --  If we were brave guys, we should attempt
      --  should be made to reconcile argument names and argument types
      --  (tricky. See how Ada compilers do parameter reconciliation with
      --  support for both named and positional parameter associations.)


      for A_Arg_Index in 1 .. Get_Count (A_Args) loop
         --  Index in Args (application layer arguments)
         declare
            A_Arg : NamedValue
              := Element_Of (List_Of (A_Args).all,
                             Integer (A_Arg_Index));
         begin
            if A_Arg.Arg_Modes = ARG_INOUT
              or else A_Arg.Arg_Modes = Direction
            then
               --  This arguments needs to be pumped up from the
               --  P_Args list.

               declare
                  P_Arg : constant NamedValue
                    := Element_Of (List_Of (P_Args).all, P_Arg_Index);
               begin
                  Copy_Any_Value (A_Arg.Argument, P_Arg.Argument);
                  --  These MUST be type-compatible!
               end;
               P_Arg_Index := P_Arg_Index + 1;
            end if;
         end;
      end loop;

   end Pump_Up_Arguments;

   procedure Arguments
     (Self : Request_Access;
      Args : in out Any.NVList.Ref)
   is
      use Any.NVList;
      use Components;

   begin
      if Is_Nil (Self.Args) then
         pragma Assert (Self.Deferred_Arguments_Session /= null);
         declare
            use Protocols.Interface;

            Reply : constant Components.Message'Class
              := Components.Emit
              (Self.Deferred_Arguments_Session,
               Unmarshall_Arguments'
               (Args => Args));
         begin
            pragma Assert (Reply in Unmarshalled_Arguments);
            Args := Unmarshalled_Arguments (Reply).Args;
            Self.Args := Args;
         end;
         Self.Deferred_Arguments_Session := null;
      else
         pragma Assert
           (Self.Deferred_Arguments_Session = null
            and then not Is_Nil (Self.Args));

         pragma Debug (O ("in Arguments: " & Image (Self.Args)));

         Pump_Up_Arguments
           (A_Args => Args, P_Args => Self.Args,
            Direction => Any.ARG_IN);
      end if;
   end Arguments;

   function Image (Req : Request) return String
   is
      S1 : constant String
        := "Operation: " & To_Standard_String (Req.Operation)
        & " on object " & References.Image (Req.Target);
   begin
      declare
         S2 : constant String := Any.NVList.Image (Req.Args);
      begin
         return S1 & " with arguments " & S2;
      end;
   exception
      when others =>
         --  Could not render arguments.
         return S1 & " with non-representable arguments";
   end Image;

end PolyORB.Requests;
