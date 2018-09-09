{-# LANGUAGE ScopedTypeVariables #-}

module CharacterActions
( attack
) where

import Apecs
import SDL.Vect
import SDL.Font

import System.Random

import Common
import Components
import Characters

-- Make one character attack another
attack :: Entity -> Entity -> System' ()
attack a v = do
  ac :: Character <- get a
  vc :: Character <- get v
  Position pos <- get v
  damage <- liftIO $ getDamage ac vc
  let vc' = dealDamage damage vc
      colour = getPopupColour (health vc') (maxHealth $ combatStats vc')
  set v vc'
  spawnFloatingText (show damage) colour pos
  if health vc' > 0 then do
    postMessage $ name ac ++ " attacks " ++ name vc' ++ " for " ++ show damage ++ " damage!"
    postMessage $ name vc' ++ " has " ++ show (health vc') ++ " health left!"
  else
    postMessage $ name ac ++ " kills " ++ name vc' ++ " with " ++ show (negate $ health vc') ++ " overkill damage!"

-- Get the damage to be dealt using the IO monad
getDamage :: Character -> Character -> IO Int
getDamage atk def = do
  r <- getStdRandom (randomR (1, strength $ stats atk))
  let dam = r
      def = 0
  pure $ max (dam - def) 0

-- Deal simple damage to enemy health
dealDamage :: Int -> Character -> Character
dealDamage d c = c { health = health c - d}

-- Get the popup colour based on health left
getPopupColour :: Int -> Int -> SDL.Font.Color
getPopupColour h max 
  | percent > 0.75 = V4 255 255 255 255
  | percent > 0.5 = V4 0 255 0 255
  | percent > 0.25 = V4 255 165 0 255
  | otherwise = V4 255 0 0 255
  where percent = fromIntegral h / fromIntegral max
