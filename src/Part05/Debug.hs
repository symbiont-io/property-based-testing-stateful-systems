{-# LANGUAGE OverloadedStrings #-}

module Part05.Debug
  (module Part05.Debug) where

import Prelude hiding (writeFile)

import Data.Aeson
import Data.ByteString.Lazy (ByteString, writeFile)
import Data.Int(Int64)
import Data.TreeDiff (ansiWlPretty, ediff, ppEditExpr)

import Part05.History
import Part05.StateMachine
import Part05.Time

------------------------------------------------------------------------

toI :: (Int, HistEvent') -> Value
toI (i, HistEvent' _dropped (HistEvent n bs inp as msgs)) = object
  [ "state" .= show (ppEditExpr ansiWlPretty (ediff bs as))
  , "currentEvent" .= object
    [ "from" .= f
    , "to" .= showN n
    , "event" .= eventName m
    , "receivedLogical" .= i
    , "message" .= m
    ]
  , "runningVersion" .= (1 :: Int64) -- TODO
  , "receivedTime" .= fromEpoch t
  , "logs" .= ([] :: [String]) -- TODO
  , "sent" .= (msgs >>= toD)
  ]
  where
    eventName = takeWhile (/= ' ')
    showN (NodeId nid)   = "Node" <> show nid
    showC (ClientId c) = "Client" <> show c
    (t, f, m) = case inp of
      ClientRequest   t' c req   -> (t', showC c, show req)
      InternalMessage t' nid msg -> (t', showN nid, show msg)
    toD (ClientResponse c resp) = pure $ object
      [ "from" .= showN n
      , "to" .= showC c
      , "event" .= eventName (show resp)
      , "receivedLogical" .= i
      , "message" .= show resp
      ]
    toD (InternalMessageOut nid msg) = pure $ object
      [ "from" .= showN nid
      , "to" .= showN nid
      , "event" .= eventName (show msg)
      , "receivedLogical" .= i
      , "message" .= show msg
      ]
    toD _ = []

toDebugFile :: [HistEvent'] -> ByteString
toDebugFile = encode . map toI . zip [0..]

writeDebugFile :: FilePath -> [HistEvent'] -> IO ()
writeDebugFile fp xs = writeFile fp (toDebugFile xs)
