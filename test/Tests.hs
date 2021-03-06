{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Tests where

import           Control.Applicative
import           Crypto.RNCryptor.V3
import qualified Data.ByteString              as B
import           Data.ByteString.Arbitrary
import qualified Data.ByteString.Char8        as C8
import           Data.Word
import           System.IO.Streams.ByteString
import           System.IO.Streams.List
import qualified Test.QuickCheck.Monadic      as M
import           Test.Tasty.HUnit
import           Test.Tasty.QuickCheck

saltSize :: Int
saltSize = 8

genHeader :: Gen RNCryptorHeader
genHeader = do
  let version = toEnum 3
  let options = toEnum 1
  eSalt    <- C8.pack <$> vector saltSize
  iv       <- C8.pack <$> vector blockSize
  hmacSalt <- C8.pack <$> vector saltSize
  return RNCryptorHeader {
        rncVersion = version
      , rncOptions = options
      , rncEncryptionSalt = eSalt
      , rncHMACSalt = hmacSalt
      , rncIV = iv
      }

newtype TestVector = TV (UserInput, UserInput, RNCryptorHeader) deriving Show

instance Arbitrary TestVector where
  arbitrary = TV <$> ((,,) <$> arbitrary <*> arbitrary <*> genHeader)

newtype UserInput = UI { unInput :: B.ByteString } deriving Show

instance Arbitrary UserInput where
  arbitrary = UI . C8.pack <$> arbitrary

newtype UserInput10M = UI10M { unInput10M :: ArbByteString10M } deriving Show

instance Arbitrary UserInput10M where
  arbitrary = UI10M <$> arbitrary

--------------------------------------------------------------------------------
testEncryptDecryptRoundtrip :: Property
testEncryptDecryptRoundtrip =
  forAll arbitrary $ \(TV (input,pwd,hdr)) ->
    B.length (unInput input) > 0 &&
    B.length (unInput pwd) > 0 ==>
    let ctx = newRNCryptorContext (unInput pwd) hdr
        encrypted = encrypt ctx (unInput input)
    in decrypt encrypted (unInput pwd) == Right (unInput input)

--------------------------------------------------------------------------------
streamingRoundTrip :: B.ByteString -> B.ByteString -> IO B.ByteString
streamingRoundTrip key plainText = do
  plainTextInS                      <- fromByteString plainText
  (cipherTextOutS, flushCipherText) <- listOutputStream
  encryptStream key plainTextInS cipherTextOutS
  cipherText                        <- flushCipherText
  cipherTextInS                     <- fromByteString (B.concat cipherText)
  (plainTextOutS, flushPlainText)   <- listOutputStream
  decryptStream key cipherTextInS plainTextOutS
  plainTexts                        <- flushPlainText
  return $ B.concat plainTexts

--------------------------------------------------------------------------------
testStreamingEncryptDecryptRoundtrip :: UserInput -> UserInput10M -> Property
testStreamingEncryptDecryptRoundtrip pwd input = M.monadicIO $ do
  input' <- M.run (streamingRoundTrip (unInput pwd) (fromABS10M (unInput10M input)))
  M.assert (fromABS10M (unInput10M input) == input')

--------------------------------------------------------------------------------
-- See: https://github.com/RNCryptor/rncryptor-hs/issues/11
testForeignEncryption :: Assertion
testForeignEncryption = do
  let swiftEncrypted = B.pack [  3,1,79,179,121,154,223,37,248,95,96,196
                              ,  77,127,26,146,150,193,56,159,119,105,170
                              ,  94,152,113,222,244,244,178,4,107,58,50,174
                              ,  90,65,21,239,127,70,137,226,152,215,144,171
                              ,  28,45,176,19,56,244,99,70,23,56,2,26,95,138
                              ,  200,203,85,110,126,200,12,93,140,140,241,0
                              ,  179,206,223,169,158,86,9,155,172
                              ]
  let swiftPassword = B.pack [112,97,115,115,119,111,114,100]
  decrypt swiftEncrypted swiftPassword @=? Right "01"
