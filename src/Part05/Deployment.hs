module Part05.Deployment
  (module Part05.Deployment) where

import Control.Concurrent.Async

import Part05.Agenda
import Part05.ClientGenerator
import Part05.Configuration
import Part05.ErrorReporter
import Part05.EventQueue
import Part05.History
import Part05.Network
import Part05.Random
import Part05.Time
import Part05.TimerWheel

------------------------------------------------------------------------

data DeploymentMode
  = Production
  | Simulation Seed Agenda History (Maybe FailureSpec) Collector
      GeneratorSchema
      RandomDist

displayDeploymentMode :: DeploymentMode -> String
displayDeploymentMode Production    = "production"
displayDeploymentMode Simulation {} = "simulation"

data Deployment = Deployment
  { dMode          :: DeploymentMode
  , dConfiguration :: Configuration
  , dClock         :: Clock
  , dEventQueue    :: EventQueue
  , dNetwork       :: Network
  , dTimerWheel    :: TimerWheel
  , dRandom        :: Random
  , dPids          :: Pids
  , dAppendHistory :: HistEvent -> IO ()
  , dReportError   :: ErrorReporter
  }

newtype Pids = Pids { unPids :: [Async ()] }

data FailureSpec = FailureSpec
  { fsNetworkFailure :: NetworkFaults
  }

newDeployment :: DeploymentMode -> Configuration -> IO Deployment
newDeployment mode config = case mode of
  Production -> do
    clock      <- realClock
    eventQueue <- realEventQueue clock
    network    <- realNetwork eventQueue clock
    timerWheel <- newTimerWheel
    random     <- realRandom
    return Deployment
      { dMode          = mode
      , dConfiguration = config
      , dClock         = clock
      , dEventQueue    = eventQueue
      , dNetwork       = network
      , dTimerWheel    = timerWheel
      , dRandom        = random
      , dPids          = Pids []
      , dAppendHistory = \_ -> return ()
      , dReportError   = putStrLn
      }
  Simulation seed agenda history mf errorCollector generatorSchema randomDist -> do
    clock      <- fakeClockEpoch
    clientGenerator <- makeGenerator generatorSchema clock
    eventQueue <- fakeEventQueue agenda clock clientGenerator
    random     <- fakeRandom seed
    network    <- faultyNetwork eventQueue clock random config history (fmap fsNetworkFailure mf) clientGenerator randomDist
    timerWheel <- newTimerWheel
    return Deployment
      { dMode          = mode
      , dConfiguration = config
      , dClock         = clock
      , dEventQueue    = eventQueue
      , dNetwork       = network
      , dTimerWheel    = timerWheel
      , dRandom        = random
      , dPids          = Pids []
      , dAppendHistory = appendHistory history DidArrive
      , dReportError   = reportWithCollector errorCollector
      }
