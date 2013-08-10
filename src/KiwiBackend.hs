{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE OverloadedStrings #-}

module KiwiBackend
    ( KiwiBackend,
      initSqliteKiwiBackend,
      getUserInfos
    ) where

import           Control.Monad
import           Control.Monad.State
import           Database.HDBC
import           Database.HDBC.Sqlite3
import           Snap.Snaplet.Auth
import           Data.Maybe
import qualified Data.Text as T
import qualified Data.HashMap.Strict as HM
import qualified Data.Aeson.Types as V
import qualified Data.Text.Encoding as E
import           Data.ByteString (ByteString)

import           KiwiAuthManager
import           Utils
import           Config


data KiwiBackend = KiwiBackend
                             { connection     :: Connection
                             , userTable      :: String
                             , usernameField  :: String
                             , characterTable :: String
                             }
initSqliteKiwiBackend :: FilePath
                         -- ^ File where is the user database
                      -> String
                         -- ^ Name of the user table
                      -> String
                         -- ^ Username field
                      -> String
                         -- ^ Name of the character table
                      -> IO (KiwiBackend)

------------------------------------------------------------------------------
-- | Create a Sqlite KiwiBackend, used to read/write data about
--   characters/users in the database. If we want to change the database
--   later, we will only need to modify this file.
initSqliteKiwiBackend path uT uF cT = do
    conn <- connectSqlite3 path
    return KiwiBackend
           { connection = conn
           , userTable = uT
           , usernameField = uF
           , characterTable = cT
           }

getUserByName :: KiwiBackend
                 -- ^ Kiwi Backend
              -> T.Text
                 -- ^ User name
              -> IO (Maybe AuthUser)
getUserByName KiwiBackend{..} name = do
  _ <- liftIO $ print "getUserLogin"
  rows <- quickQuery' connection query [toSql . T.unpack $ name]
  computeRows rows
  where
    query = "SELECT `id`, `name`, `password`, `email`, `salt`, `lastLoginIp`, `lastLoginAt`, `createdAt` FROM `" ++ userTable ++ "` WHERE `"++ usernameField ++"`=?"

getUserById :: KiwiBackend
                 -- ^ Kiwi Backend
              -> UserId
                 -- ^ User name
              -> IO (Maybe AuthUser)
getUserById KiwiBackend{..} id = do
  _ <- liftIO $ print "getUserID"
  rows <- quickQuery' connection query [toSql (read . T.unpack . unUid $ id :: Int)]
  computeRows rows
  where
    query = "SELECT `id`, `name`, `password`, `email`, `salt`, `lastLoginIp`, `lastLoginAt`, `createdAt` FROM `" ++ userTable ++ "` WHERE `id`=?"


computeRows :: [[SqlValue]] -> IO (Maybe AuthUser)
computeRows rows = case rows of
  [] -> return Nothing
  row : _ -> let [id, name, password, email, salt, lli, lla, ca] = row in
    return $ Just defAuthUser
        { userId = Just UserId {unUid = T.pack . show $ (fromSql id :: Int)}
        , userLogin = fromSql name
        , userPassword = Just . ClearText . fromSql $ password
        , userEmail = fromSql email
        , userMeta = HM.fromList ["salt" `quickMeta` fromSql salt]
        }

getUserInfos :: KiwiBackend -> UserId -> IO [(String, String)]
getUserInfos KiwiBackend{..} id = do
  rows <- quickQuery' connection query [toSql (read . T.unpack . unUid $ id :: Int)]
  return $ case rows of
    row : _ -> zip fields (map fromSql row)
    _       -> []
  where
    fields = ["userName", "userEmail", "userFirstName", "userLastName", "userBirthday",
              "userLastLoginIp", "userLastLoginAt", "userCreatedAt"]
    query = "SELECT `name`, `email`, `first_name`, `last_name`, `birthday`, `lastLoginIp`, `lastLoginAt`, `createdAt` FROM `" ++ userTable ++ "` WHERE `id`=?"

addUser :: KiwiBackend
           -- ^ Kiwi Backend
        -> T.Text
           -- ^ Username
        -> ByteString
           -- ^ Crypted password
        -> ByteString
           -- ^ Salt
        -> T.Text
           -- ^ Email
        -> IO (Either AuthFailure AuthUser)
addUser b@KiwiBackend{..} username password salt email = do
  _ <- liftIO $ print "getUserLogin"
  -- Save user
  run connection query [toSql username, toSql password, toSql salt, toSql email]
  -- Load the user and it's id from
  mbAuthUser <- getUserByName b username
  commit connection
  return . Right . fromJust $ mbAuthUser
  where
    query = "INSERT INTO `" ++ userTable ++ "` (`name`, `password`, `salt`, `email`) VALUES (?, ?, ?, ?)"


instance KiwiAuthBackend KiwiBackend where
  --TODO : do not allow any characters for field username
  register = addUser
  lookupByName = getUserByName
  lookupById = getUserById
  delete = error "delete not yet implemented"

