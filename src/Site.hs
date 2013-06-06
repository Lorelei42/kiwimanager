{-# LANGUAGE OverloadedStrings #-}

------------------------------------------------------------------------------
-- | This module is where all the routes and handlers are defined for your
-- site. The 'app' function is the initializer that combines everything
-- together and is exported by this module.
module Site
  ( app
  ) where

------------------------------------------------------------------------------
import           Data.ByteString (ByteString)
import           Snap
import           Snap.Snaplet
import           Snap.Snaplet.Heist
import           Snap.Util.FileServe
import           Heist
import           Heist.Interpreted

import qualified Data.Text as T
import           Data.IORef
------------------------------------------------------------------------------
import           Application
import           Config
import           Status


------------------------------------------------------------------------------
-- | The application's routes.
routes :: [(ByteString, Handler App App ())]
routes = [ ("",          serveDirectory "static")
         ]

------------------------------------------------------------------------------
-- | The application's splices.
splices :: [(T.Text, SnapletISplice App)]
splices = [ ("server_status", statusSplice)
          , ("navbar",        callTemplate "_nav_non-auth" [])
          ]

------------------------------------------------------------------------------
-- | The status splice
statusSplice :: SnapletISplice App
statusSplice = do
  if False then textSplice "on" else textSplice "off"

------------------------------------------------------------------------------
-- | The application initializer.
app :: SnapletInit App App
app = makeSnaplet "app" "KiwiMonitor application." Nothing $ do
    h <- nestSnaplet "" heist $ heistInit "templates"
    addRoutes routes
    addSplices splices
    ss <- liftIO $ newIORef False
    return $ App h ss defaultConfiguration

