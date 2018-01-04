{ mkDerivation, base, base16-bytestring, bytestring
, bytestring-arbitrary, criterion, cryptonite, fastpbkdf2
, io-streams, memory, mtl, QuickCheck, random, stdenv, tasty
, tasty-hunit, tasty-quickcheck, text
}:
mkDerivation {
  pname = "rncryptor";
  version = "0.3.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    base bytestring cryptonite fastpbkdf2 io-streams memory mtl random
  ];
  executableHaskellDepends = [
    base bytestring cryptonite io-streams
  ];
  testHaskellDepends = [
    base base16-bytestring bytestring bytestring-arbitrary cryptonite
    io-streams QuickCheck tasty tasty-hunit tasty-quickcheck text
  ];
  benchmarkHaskellDepends = [ base bytestring criterion ];
  description = "Haskell implementation of the RNCryptor file format";
  license = stdenv.lib.licenses.mit;
}
