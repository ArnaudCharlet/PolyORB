--  The messages supported by ORBs (middleware core module).

--  $Id$

with Droopi.Components;
with Droopi.Jobs;
with Droopi.Requests;

package Droopi.ORB.Interface is

   type Queue_Job is new Components.Message with record
      Job : Droopi.Jobs.Job_Access;
   end record;
   --  Queue Job for execution by the receiving ORB.
   --  No reply (the job will be executed asynchronously).

   type Queue_Request is new Components.Message with record
      Request   : Requests.Request_Access;
      Requestor : Components.Component_Access;
   end record;
   --  Queue method invocation request Req for execution by Server
   --  on behalf of a remote caller. No reply expected.
   --  When the request is executed, a message will be sent
   --  back to Requestor (asynchronously).
   --  The client is the responsible of the destruction of
   --  the Request.

end Droopi.ORB.Interface;
