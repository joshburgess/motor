{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PolyKinds                  #-}
{-# LANGUAGE RebindableSyntax           #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
module Motor.FSMSpec.Game where

import           Prelude                hiding (log)

import           Control.Monad.Indexed
import           Control.Monad.IO.Class
import           Data.OpenRecords

import           Motor.FSM
import           Motor.FSM.Logging

-- * Game Protocol/Machine

data Standing
data Jumping

class MonadFSM m => Game (m :: Row * -> Row * -> * -> *) where
  type State m :: * -> *
  spawn :: KnownSymbol n => Name n -> m r (n ::= State m Standing :| r) ()
  jump :: KnownSymbol n => Name n -> m r (n ::= State m Jumping :| (r :- n)) ()
  land :: KnownSymbol n => Name n -> m r (n ::= State m Standing :| (r :- n)) ()
  perish :: KnownSymbol n => Name n -> m r (r :- n) ()

-- * Game Implemention

newtype GameImpl m (i :: Row *) (o :: Row *) a =
  GameImpl { runGameImpl :: FSM m i o a }
  deriving (IxFunctor, IxPointed, IxApplicative, IxMonad, MonadFSM)

deriving instance Monad m => Functor (GameImpl m i i)

deriving instance Monad m => Applicative (GameImpl m i i)

deriving instance Monad m => Monad (GameImpl m i i)

instance (MonadIO m) => MonadIO (GameImpl m i i) where
  liftIO = GameImpl . liftIO

data GameState s where
  Standing :: GameState Standing
  Jumping :: GameState Jumping

instance (MonadIO m, Monad m) => Game (GameImpl m) where
  type State (GameImpl m) = GameState
  spawn n =
    log n "Spawning player."
    >>>= const (new n Standing)
  jump n =
    log n "Huuuhhh!"
    >>>= const (enter n Jumping)
  land n =
    log n "Back on safe ground."
    >>>= const (enter n Standing)
  perish n =
    log n "Aaaaarhhh..."
    >>>= const (delete n)

hero1 :: Name "hero1"
hero1 = Name

hero2 :: Name "hero2"
hero2 = Name

testTwoAdds ::
     Game m
  => Actions m '[ "hero2" !+ State m Standing
                , "hero1" !+ State m Standing
                ] r ()
testTwoAdds =
  spawn hero1 >>>= \_ -> spawn hero2

testTwoDeletes ::
     Game m
  => Actions m '[ "hero2" !- State m Standing, "hero1" !- State m Standing] r ()
testTwoDeletes =
  perish hero1 >>>= \_ -> perish hero2

testTwoAddDeletes ::
     Game m
  => Actions m '[ "hero2" !- State m Standing
                , "hero1" !- State m Standing
                , "hero2" !+ State m Standing
                , "hero1" !+ State m Standing
                ] r ()
testTwoAddDeletes = do
  spawn hero1
  spawn hero2
  perish hero1
  perish hero2
  where
    (>>) a = (>>>=) a . const

testGame :: Game m => OnlyActions m '[] ()
testGame = testTwoAdds >> testTwoDeletes
  where
    (>>) a = (>>>=) a . const


run :: Monad m => GameImpl m Empty Empty () -> m ()
run g = runFSM (runGameImpl g)

runIO :: IO ()
runIO = do
  run testGame
  putStrLn "Game over."