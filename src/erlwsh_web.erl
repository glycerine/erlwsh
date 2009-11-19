%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc Web server for erlwsh.

-module(erlwsh_web).
-author('author <author@example.com>').

-export([start/1, stop/0, loop/2]).

%% External API

start(Options) ->
    {DocRoot, Options1} = get_option(docroot, Options),
    Loop = fun (Req) ->
                   ?MODULE:loop(Req, DocRoot)
           end,
    mochiweb_http:start([{name, ?MODULE}, {loop, Loop} | Options1]).

stop() ->
    mochiweb_http:stop(?MODULE).

loop(Req, DocRoot) ->
    "/" ++ Path = Req:get(path),
    case Req:get(method) of
        Method when Method =:= 'GET'; Method =:= 'HEAD' ->
            case Path of
                 "shell" ->
                    Socket=Req:get(socket),
                    Addr=Req:get(peer),
                    Port=integer_to_list(get_port(Socket)),
                    Name=list_to_atom(Addr ++ ":" ++ Port),
                    register(Name,self()),
                    N=1,
                    NameField=get_name_field(Name),                
                    Response = Req :ok ( { "text/html; charset=utf-8" ,
                                     [ { "Server" ,"Erlang-web-shell" } ] ,
                                     chunked} ) ,
                    Response :write_chunk ( "<html><head><title>Erlang web shell 0.01</title>"
                                            "<script type='text/javascript' language='javascript' src='prototype.js' ></script>"
                                            "<script type='text/javascript' language='javascript'>
                                                 function post_str(event){
                                                     if(event.keyCode==13){
                                                       var e=Event.element(event);
                                                       var value=e.value;
                                                       var pattern=/.*\\.$/;
                                                       if(!pattern.test(value))
                                                            return;
                                                       disable_input(e);
                                                       new Ajax.Request(
                                                          'shell',
                                                          {
                                                            method: 'post',
                                                            parameters:Form.serialize(e.parentNode),
                                                            onComplete: function(){}
                                                          }
                                                       );
                                                    }
                                                 }
                                                 function disable_input(str){
                                                       str.style.border='0px;';
                                                       str.readOnly=true;
                                                 }
                                            </script></head>"
                                            "<body> Erlang web shell 0.01 (dennis:killme2008@gmail.com)</br>" ++
                                            get_form(NameField,N)) ,
                    loop(NameField,Response,erl_eval:new_bindings(), N);

                _ ->
                    Req:serve_file(Path, DocRoot)
            end;
        'POST' ->
            case Path of
               "shell" ->
                   Params=Req:parse_post(),
                   Str=proplists:get_value("str",Params),
                   Pid=list_to_atom(proplists:get_value("name",Params)),
                   Pid ! {post_msg,Str},
                   Req:ok({"text/plain", "success"});                   
                _ ->
                    Req:not_found()
            end;
        _ ->
            Req:respond({501, [], []})
    end.

get_name_field(Name)->
     io_lib:format("<input type='hidden' name='name' value=~p/>",[Name]).

get_form(NameField,N)->
    io_lib:format("~p&gt;<form name='form~p' onsubmit='return false;'>
              <input name='str' type='text' size='%100'
              style='border-top-style:none;border-right-style:none;border-left-style:none;border-bottom-style:1px;'
              onkeydown='post_str(event)'/>
              <script type='text/javascript' language='javascript'> $('form~p').str.focus(); </script>
              ",[N,N,N]) ++
               NameField ++
              " </form>".

get_port(Socket) ->
    case inet:peername(Socket) of       
        {ok, {_Addr, Port}} ->
            Port
    end.

%% Internal API
loop(NameField, Response,Binding ,N ) ->
    receive
        {post_msg,Str}->
             try eshell:eval(Str,Binding) of
                {value,Value,NewBinding} ->
                       Response:write_chunk(io_lib:format("~p</br>",[Value]) ++ get_form(NameField,N+1)), 
	               loop(NameField,Response,NewBinding,N+1)
             catch
                   _:Why->
                       Response:write_chunk(io_lib:format("~p</br>",[Why]) ++ get_form(NameField,N+1)), 
	               loop(NameField,Response,Binding,N+1)
            end          
    end.

get_option(Option, Options) ->
    {proplists:get_value(Option, Options), proplists:delete(Option, Options)}.