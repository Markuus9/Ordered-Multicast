-module(total).
-export([start/3]).

%% Inicia el proceso del Total Order Multicast
start(Id, Master, Jitter) ->
    spawn(fun() -> init(Id, Master, Jitter) end).

init(Id, Master, Jitter) ->
    {A1,A2,A3} = now(),
    random:seed(A1, A2, A3),
    receive
        {peers, Nodes} ->
            %% Inicializa el servidor con el estado inicial
            server(Master, seq:new(Id), seq:new(Id), Nodes, [], [], Jitter)
    end.

%% Loop principal del servidor
server(Master, MaxPrp, MaxAgr, Nodes, Cast, Queue, Jitter) ->
    receive
        %% 1. Enviar mensaje (Send)
        {send, Msg} ->
            Ref = make_ref(), %% Crea una referencia única para el mensaje
            request(Ref, Msg, Nodes, Jitter), %% Envía solicitudes de propuesta
            NewCast = cast(Ref, Nodes, Cast), %% Añade el mensaje al conjunto Cast
            server(Master, MaxPrp, MaxAgr, Nodes, NewCast, Queue, Jitter);

        %% 2. Manejar solicitud de propuesta (Request)
        {request, From, Ref, Msg} ->
            %% Calcula el nuevo número de secuencia propuesto
            NewMaxPrp = seq:increment(seq:max(MaxPrp, MaxAgr)),
            From ! {proposal, Ref, NewMaxPrp}, %% Envía la propuesta al remitente
            %% Inserta el mensaje con la propuesta en la cola local
            NewQueue = insert(Ref, Msg, NewMaxPrp, Queue),
            server(Master, NewMaxPrp, MaxAgr, Nodes, Cast, NewQueue, Jitter);

        %% 3. Procesar propuesta (Proposal)
        {proposal, Ref, Proposal} ->
            %% Procesa la propuesta recibida y verifica si se alcanza un acuerdo
            case proposal(Ref, Proposal, Cast) of
                {agreed, MaxSeq, NewCast} ->
                    agree(Ref, MaxSeq, Nodes), %% Envía el acuerdo a todos los nodos
                    server(Master, MaxPrp, MaxAgr, Nodes, NewCast, Queue, Jitter);
                NewCast ->
                    server(Master, MaxPrp, MaxAgr, Nodes, NewCast, Queue, Jitter)
            end;

        %% 4. Manejar acuerdo (Agreed)
        {agreed, Ref, Seq} ->
            %% Actualiza la cola con el número de secuencia acordado
            Updated = update(Ref, Seq, Queue),
            {Agreed, NewQueue} = agreed(Updated), %% Extrae mensajes listos para entregar
            deliver(Master, Agreed), %% Entrega mensajes al maestro
            %% Actualiza el máximo número de secuencia acordado
            NewMaxAgr = seq:max(MaxAgr, Seq),
            server(Master, MaxPrp, NewMaxAgr, Nodes, Cast, NewQueue, Jitter);

        %% 5. Finalizar (Stop)
        stop ->
            ok
    end.

%% Enviar una solicitud de propuesta a todos los nodos
request(Ref, Msg, Nodes, 0) ->
    Self = self(),
    lists:foreach(fun(Node) -> 
                      Node ! {request, Self, Ref, Msg} %% Envía directamente si jitter es 0
                  end, 
                  Nodes);
request(Ref, Msg, Nodes, Jitter) ->
    Self = self(),
    lists:foreach(fun(Node) ->
                      %% Simula un retraso de red aleatorio
                      T = random:uniform(Jitter),
                      timer:send_after(T, Node, {request, Self, Ref, Msg})
                  end,
                  Nodes).
        
%% Enviar un mensaje de acuerdo a todos los nodos
agree(Ref, Seq, Nodes)->
    lists:foreach(fun(Pid)-> 
                      Pid ! {agreed, Ref, Seq} %% Envía el acuerdo con el número de secuencia final
                  end, 
                  Nodes).

%% Entregar mensajes al maestro
deliver(Master, Messages) ->
    lists:foreach(fun(Msg)-> 
                      Master ! {deliver, Msg} %% Informa al maestro de cada mensaje entregado
                  end, 
                  Messages).
                  
%% Añadir un nuevo mensaje al conjunto Cast
cast(Ref, Nodes, Cast) ->
    L = length(Nodes),
    [{Ref, L, seq:null()}|Cast].

%% Actualizar el conjunto Cast con propuestas y acuerdos
proposal(Ref, Proposal, [{Ref, 1, Sofar}|Rest])->
    {agreed, seq:max(Proposal, Sofar), Rest};
proposal(Ref, Proposal, [{Ref, N, Sofar}|Rest])->
    [{Ref, N-1, seq:max(Proposal, Sofar)}|Rest];
proposal(Ref, Proposal, [Entry|Rest])->
    case proposal(Ref, Proposal, Rest) of
        {agreed, Agreed, Rst} ->
            {agreed, Agreed, [Entry|Rst]};
        Updated ->
            [Entry|Updated]
    end.
    
%% Eliminar todos los mensajes al frente de la cola que ya tienen un acuerdo
agreed([{_Ref, Msg, agrd, _Agr}|Queue]) ->
    {Agreed, Rest} = agreed(Queue),
    {[Msg|Agreed], Rest};
agreed(Queue) ->
    {[], Queue}.
    
%% Actualizar la cola con un número de secuencia acordado
update(Ref, Agreed, [{Ref, Msg, propsd, _}|Rest])->
    queue(Ref, Msg, agrd, Agreed, Rest);
update(Ref, Agreed, [Entry|Rest])->
    [Entry|update(Ref, Agreed, Rest)].
    
%% Insertar un nuevo mensaje en la cola
insert(Ref, Msg, Proposal, Queue) ->
    queue(Ref, Msg, propsd, Proposal, Queue).
    
%% Añadir un nuevo mensaje a la cola de manera ordenada
queue(Ref, Msg, State, Proposal, []) ->
    [{Ref, Msg, State, Proposal}];
queue(Ref, Msg, State, Proposal, Queue) ->
    [Entry|Rest] = Queue,
    {_, _, _, Next} = Entry,
    case seq:lessthan(Proposal, Next) of
        true ->
            [{Ref, Msg, State, Proposal}|Queue];
        false ->
            [Entry|queue(Ref, Msg, State, Proposal, Rest)]
    end.

