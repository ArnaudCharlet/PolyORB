--  Information about running ORB tasks.
--  This packages is used to store and retrieve information
--  concerning the status of tasks that execute ORB functions.

--  $Id$

with Droopi.Asynch_Ev;
with Droopi.Soft_Links;

package Droopi.Task_Info is

   pragma Elaborate_Body;

   type Task_Kind is (Permanent, Transient);
   --  A Permanent task executes ORB.Run indefinitely.
   --  A Transient task executes ORB.Run until a given condition
   --  is met. Transient tasks are lent to the middleware by
   --  user activities.

   type Task_Status is (Running, Blocked, Idle);
   --  A Running task is executing an ORB activity.
   --  A Blocked task is waiting for an external
   --  asynchronous event.
   --  An Idle task is waiting on a watcher expecting another
   --  task to request ORB action.

   type Task_Info (Kind : Task_Kind) is limited private;
   type Task_Info_Access is access all Task_Info;

   procedure Set_Status_Blocked
     (TI       : in out Task_Info;
      Selector : Asynch_Ev.Asynch_Ev_Monitor_Access);
   pragma Inline (Set_Status_Blocked);

   procedure Set_Status_Idle
     (TI      : in out Task_Info;
      Watcher : Soft_Links.Watcher_Access);
   pragma Inline (Set_Status_Idle);

   procedure Set_Status_Running
     (TI : in out Task_Info);
   pragma Inline (Set_Status_Running);

   function Status (TI : Task_Info)
     return Task_Status;
   pragma Inline (Status);

   function Selector (TI : Task_Info)
     return Asynch_Ev.Asynch_Ev_Monitor_Access;
   pragma Inline (Selector);

   function Watcher (TI : Task_Info)
     return Soft_Links.Watcher_Access;
   pragma Inline (Watcher);

private

   type Task_Info (Kind : Task_Kind) is record
      Status : Task_Status := Running;

      Selector : Asynch_Ev.Asynch_Ev_Monitor_Access;
      --  Meaningful only when Status = Blocked

      Watcher  : Soft_Links.Watcher_Access;
      --  Meaningful only when Status = Idle
   end record;

end Droopi.Task_Info;
