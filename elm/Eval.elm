module Eval exposing (..)

import Types exposing (..)
import IO exposing (IO)
import Env


apply : Eval a -> Env -> EvalContext a
apply f env =
    f env


run : Env -> Eval a -> EvalContext a
run env e =
    apply e env


withEnv : (Env -> Eval a) -> Eval a
withEnv f env =
    apply (f env) env


setEnv : Env -> Eval ()
setEnv env _ =
    apply (succeed ()) env


modifyEnv : (Env -> Env) -> Eval ()
modifyEnv f env =
    apply (succeed ()) (f env)


succeed : a -> Eval a
succeed res env =
    ( env, EvalOk res )


io : Cmd Msg -> (IO -> Eval a) -> Eval a
io cmd cont env =
    ( env, EvalIO cmd cont )


map : (a -> b) -> Eval a -> Eval b
map f e env =
    case apply e env of
        ( env, EvalOk res ) ->
            ( env, EvalOk (f res) )

        ( env, EvalErr msg ) ->
            ( env, EvalErr msg )

        ( env, EvalIO cmd cont ) ->
            ( env, EvalIO cmd (cont >> map f) )


{-| Chain two Eval's together. The function f takes the result from
the left eval and generates a new Eval.
-}
andThen : (a -> Eval b) -> Eval a -> Eval b
andThen f e env =
    case apply e env of
        ( env, EvalOk res ) ->
            apply (f res) env

        ( env, EvalErr msg ) ->
            ( env, EvalErr msg )

        ( env, EvalIO cmd cont ) ->
            ( env, EvalIO cmd (cont >> andThen f) )


{-| Apply a transformation to the Env, for a Ok and a Err.
-}
finally : (Env -> Env) -> Eval a -> Eval a
finally f e env =
    case apply e env of
        ( env, EvalOk res ) ->
            ( f env, EvalOk res )

        ( env, EvalErr msg ) ->
            ( f env, EvalErr msg )

        ( env, EvalIO cmd cont ) ->
            ( env, EvalIO cmd (cont >> finally f) )


catchError : (MalExpr -> Eval a) -> Eval a -> Eval a
catchError f e env =
    case apply e env of
        ( env, EvalOk res ) ->
            ( env, EvalOk res )

        ( env, EvalErr msg ) ->
            apply (f msg) env

        ( env, EvalIO cmd cont ) ->
            ( env, EvalIO cmd (cont >> catchError f) )


fail : String -> Eval a
fail msg env =
    ( env, EvalErr <| MalString msg )


throw : MalExpr -> Eval a
throw ex env =
    ( env, EvalErr ex )


enter : Int -> List ( String, MalExpr ) -> Eval a -> Eval a
enter frameId bound body =
    withEnv
        (\env ->
            modifyEnv (Env.enter frameId bound)
                |> andThen (always body)
                |> andThen
                    (\res ->
                        modifyEnv (Env.leave env.currentFrameId)
                            |> map (always res)
                    )
        )


{-| Apply f to expr repeatedly.
Continues iterating if f returns (Left eval).
Stops if f returns (Right expr).

Tail call optimized.

-}
runLoop : (MalExpr -> Env -> Either (Eval MalExpr) MalExpr) -> MalExpr -> Eval MalExpr
runLoop f expr env =
    case f expr env of
        Left e ->
            case apply e env of
                ( env, EvalOk expr ) ->
                    runLoop f expr env

                ( env, EvalErr msg ) ->
                    ( env, EvalErr msg )

                ( env, EvalIO cmd cont ) ->
                    ( env, EvalIO cmd (cont >> andThen (runLoop f)) )

        Right expr ->
            ( env, EvalOk expr )


fromResult : Result String a -> Eval a
fromResult res =
    case res of
        Ok val ->
            succeed val

        Err msg ->
            fail msg


{-| Chain the left and right Eval but ignore the right's result.
-}
ignore : Eval b -> Eval a -> Eval a
ignore right left =
    left
        |> andThen
            (\res ->
                right
                    |> andThen (\_ -> succeed res)
            )
