program asyncsrv;
//
//  Asynchronous client-to-server (DEALER to ROUTER)
//
//  While this example runs in a single process, that is just to make
//  it easier to start and stop the example. Each task has its own
//  context and conceptually acts as a separate process.

{$APPTYPE CONSOLE}

uses
    SysUtils
  , Classes
  , zmqapi
  ;

//  ---------------------------------------------------------------------
//  This is our client task
//  It connects to the server, and then sends a request once per second
//  It collects responses as they arrive, and it prints them out. We will
//  run several client tasks in parallel, each with a different random ID.

procedure client_task( args: Pointer );
var
  ctx: TZMQContext;
  client: TZMQSocket;
  poller: TZMQPoller;
  pr: TZMQPollResult;
  i, pc, request_nbr: Integer;
  tsl: TStringList;
begin
  ctx := TZMQContext.create;
  client := ctx.Socket( stDealer );

  //  Set random identity to make tracing easier
  client.Identity := IntToHex( Integer(client),8 );
  client.connect( 'tcp://localhost:5570' );

  poller := TZMQPoller.Create;
  poller.regist( client, [pePollIn] );

  tsl := TStringList.Create;
  
  request_nbr := 0;
  while true do
  begin
    //  Tick once per second, pulling in arriving messages
    for i := 0 to 100 - 1 do
    begin
      pc := poller.poll( 10 );
      if ( pc > 0 ) then
      begin
        pr := poller.pollResult[0];
        pr.socket.recv( )
      end;
    end;

  end;

end;

    zmq_pollitem_t items [] = { { client, 0, ZMQ_POLLIN, 0 } };
    int request_nbr = 0;
    while (true) {
        //  Tick once per second, pulling in arriving messages
        int centitick;
        for (centitick = 0; centitick < 100; centitick++) {
            zmq_poll (items, 1, 10 * ZMQ_POLL_MSEC);
            if (items [0].revents & ZMQ_POLLIN) {
                zmsg_t *msg = zmsg_recv (client);
                zframe_print (zmsg_last (msg), identity);
                zmsg_destroy (&msg);
            }
        }
        zstr_sendf (client, "request #%d", ++request_nbr);
    }
    zctx_destroy (&ctx);
    return NULL;
}


begin

end.

#include "czmq.h"


static void *

//  This is our server task.
//  It uses the multithreaded server model to deal requests out to a pool
//  of workers and route replies back to clients. One worker can handle
//  one request at a time but one client can talk to multiple workers at
//  once.

static void server_worker (void *args, zctx_t *ctx, void *pipe);

void *server_task (void *args)
{
    zctx_t *ctx = zctx_new ();

    //  Frontend socket talks to clients over TCP
    void *frontend = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (frontend, "tcp://*:5570");

    //  Backend socket talks to workers over inproc
    void *backend = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_bind (backend, "inproc://backend");

    //  Launch pool of worker threads, precise number is not critical
    int thread_nbr;
    for (thread_nbr = 0; thread_nbr < 5; thread_nbr++)
        zthread_fork (ctx, server_worker, NULL);

    //  Connect backend to frontend via a proxy
    zmq_proxy (frontend, backend, NULL);

    zctx_destroy (&ctx);
    return NULL;
}

//  Each worker task works on one request at a time and sends a random number
//  of replies back, with random delays between replies:

static void
server_worker (void *args, zctx_t *ctx, void *pipe)
{
    void *worker = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_connect (worker, "inproc://backend");

    while (true) {
        //  The DEALER socket gives us the address envelope and message
        zmsg_t *msg = zmsg_recv (worker);
        zframe_t *address = zmsg_pop (msg);
        zframe_t *content = zmsg_pop (msg);
        assert (content);
        zmsg_destroy (&msg);

        //  Send 0..4 replies back
        int reply, replies = randof (5);
        for (reply = 0; reply < replies; reply++) {
            //  Sleep for some fraction of a second
            zclock_sleep (randof (1000) + 1);
            zframe_send (&address, worker, ZFRAME_REUSE + ZFRAME_MORE);
            zframe_send (&content, worker, ZFRAME_REUSE);
        }
        zframe_destroy (&address);
        zframe_destroy (&content);
    }
}

//  The main thread simply starts several clients, and a server, and then
//  waits for the server to finish.

int main (void)
{
    zctx_t *ctx = zctx_new ();
    zthread_new (client_task, NULL);
    zthread_new (client_task, NULL);
    zthread_new (client_task, NULL);
    zthread_new (server_task, NULL);

    //  Run for 5 seconds then quit
    zclock_sleep (5 * 1000);
    zctx_destroy (&ctx);
    return 0;
}