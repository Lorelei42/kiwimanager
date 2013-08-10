{-# LANGUAGE TemplateHaskell #-}

------------------------------------------------------------------------------
-- | This module defines our application's state type and an alias for its
-- handler monad.
module Application where

------------------------------------------------------------------------------
import Control.Lens
import Snap.Snaplet
import Snap.Snaplet.Heist
import Snap.Snaplet.Auth
import Snap.Snaplet.Session
import KiwiBackend
import Data.IORef

------------------------------------------------------------------------------
import Status

------------------------------------------------------------------------------
data App = App
    { _heist        :: Snaplet (Heist App)
    , _sess         :: Snaplet SessionManager
    , _auth         :: Snaplet (AuthManager App)
    , _serverStatus :: IORef Bool
    , _kiwiDB       :: KiwiBackend
    }

makeLenses ''App

instance HasHeist App where
    heistLens = subSnaplet heist


------------------------------------------------------------------------------
type AppHandler = Handler App App


