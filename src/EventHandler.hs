{-# LANGUAGE ScopedTypeVariables #-}

module EventHandler
( handlePayload
) where

import Apecs hiding (Map)
import SDL hiding (get)

import Control.Monad(when)
import Control.Monad.IO.Class
import Data.Maybe(isNothing)
import Data.List(find)

import Common hiding (Left, Right, Down, Up)
import qualified Common as C
import Components
import GameMap
import Characters

-- Handle the entire event payload
handlePayload :: [EventPayload] -> System' ()
handlePayload = mapM_ handleEvent 
  
-- The main event handler function for dealing with keypresses
handleEvent :: EventPayload -> System' ()
handleEvent (KeyboardEvent ev) = handleKeyEvent ev
handleEvent _ = pure ()

-- For the handling keyboard events only
handleKeyEvent :: KeyboardEventData -> System' ()
handleKeyEvent ev = do
  (state :: GameState) <- get global
  let code = keysymKeycode $ keyboardEventKeysym ev
  case keyboardEventKeyMotion ev of
    Pressed ->
      case state of
        Game mode -> gameAction mode code
        Interface -> postMessage "Interface state not implemented yet"
    Released -> pure ()

-- Use GameState to determine the context of input
-- Use context specific bindings to ascertain intent
data GameIntent
  = Navigate Direction
  | ToggleLook
  deriving (Read, Show, Eq)

-- Initial bindings for intents
defaultGameIntents :: [(Keycode, GameIntent)]
defaultGameIntents = 
  [ (KeycodeUp , Navigate C.Up)
  , (KeycodeK, Navigate C.Up)
  , (KeycodeLeft , Navigate C.Left)
  , (KeycodeH, Navigate C.Left)
  , (KeycodeDown , Navigate C.Down)
  , (KeycodeJ, Navigate C.Down)
  , (KeycodeRight , Navigate C.Right)
  , (KeycodeL, Navigate C.Right)
  ]

-- For keyboard events that  take place in the game
gameAction :: GameMode -> Keycode -> System' ()
gameAction mode k = case mode of
  Standard -> 
    case lookup k defaultGameIntents of
      Just (Navigate dir) -> navigate dir
      Just ToggleLook -> postMessage "Toggle look not implemented yet."
      _ -> pure ()
  Look -> postMessage "Modes other than standard not supported yet."

-- Things that can come from navigation
data NavAction = Move | Swap Entity | Fight Entity deriving Show

-- Move, swap, or fight in a given direction, standard navigation
navigate :: Direction -> System' ()
navigate dir = do
  GameMap m <- get global
  [(Player, CellRef (V2 x y), p)] <- getAll
  chars :: CharacterList <- getAll
  let (V2 i j) = directionToVect dir
      dest = V2 (x + i) (y + j)
      valid = getNavAction m (dir, dest) chars
  case valid of
    Left (na, msg) -> do
      case na of
        Move -> 
          modify p (\(CellRef _) -> CellRef dest)
        Swap e -> do
          CellRef (V2 eX eY) <- get e
          modify e (\(CellRef _) -> CellRef (V2 x y))
          modify p (\(CellRef _) -> CellRef (V2 eX eY))
        Fight e -> 
          destroy e (Proxy :: Proxy AllComps)
      postMessage msg
    Right msg -> 
      postMessage msg

-- Given a direction, find how to execute the player's intent
getNavAction :: Grid -> (Direction, V2 Int) -> CharacterList -> Either (NavAction, String) String
getNavAction g (dir, dest) cs = 
  case tile of
    Nothing -> Right "Hmm.. You can't find a way to move there."
    Just tile -> 
      if tile == Empty
        then case charOnSpace of
          Nothing -> Left (Move, "You move " ++ show dir ++ ".")
          Just (c, _, e) -> 
            case attitude c of
              Aggressive -> Left (Fight e, "You murder " ++ name c ++ "!")
              Friendly -> Left (Swap e, "You switch places with " ++ name c ++ "!")
              Neutral -> Right $ "Oof! You bumped into " ++ name c ++ "!"
        else Right "Ouch! You bumped into a wall!"
  where tile = getTile g dest
        chk (Character {}, CellRef p, _) = dest == p
        charOnSpace = find chk cs
