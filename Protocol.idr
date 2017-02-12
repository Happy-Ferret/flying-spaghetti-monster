module Protocol
import Data.List

%access public export
%default total

-- A Choice is a type representing a discrete set of alternatives.
data Choice : List a -> Type
where Choose : (alternative : a) ->
               {alternatives : List a} ->
               {auto membershipProof : Elem alternative alternatives} ->
               Choice alternatives

-- A path between a source and a destination state.
Path : Type
Path = (String, String)

-- A named path.
Transition : Type
Transition = (String, Path)

-- Read a list of transitions from a file.
readTransitions : String -> IO (Either FileError (List Transition))
readTransitions filename =
  do result <- readFile filename
     pure $ map (pair . words) result
  where pair : List String -> List Transition
        pair (name::source::destination::rest) = (name, (source, destination))::(pair rest)
        pair _ = []

-- Use the allowed transitions to define a finite state machine type.
data Command : Type -> Type -> (transition -> Path) -> Path -> Type
where
  Begin : Command () transition deconstruct (state, state)

  Then  : (t : transition) ->
          Command () transition deconstruct (deconstruct t)

  (>>=) : Command a transition deconstruct (beginning, middle) ->
          (a -> Command b transition deconstruct (middle, end)) ->
          Command b transition deconstruct (beginning, end)

-- Encode a list of transitions into a session type.
encode : List Transition -> Path -> Type
encode transitions = Command () (Choice transitions) single
  where single : {auto xs : List Transition} -> (Choice xs) -> Path
        single (Choose (_, x)) = x

-- A type provider providing a list of steps.
Protocol : String -> IO (Provider (Path -> Type))
Protocol filename =
  do result <- readTransitions filename
     pure $
       case result of
         Left error => Error $ "Unable to read transitions file: " ++ filename
         Right transitions => Provide $ encode transitions
