module Semantic.Analyzers where
import Tokens
import qualified AST
import Parser.Monad (ParserMonad)
import Parser.Monad as PMonad
import qualified Semantic.Data as Sem
import Data.Maybe
import qualified Control.Monad.RWS.Lazy as RWS
import Control.Monad.Trans
import Util.Error

-- | Throws a semantic error
semError :: Token -> String -> ParserMonad a
semError tk msg = do
    srcFile <- RWS.ask
    throwCompilerError srcFile [Error (line tk) (col tk) msg]
   
-- | Throw a semantic error if Maybe is Nothing
throwIfNothing :: Maybe a -> Token -> String ->  ParserMonad a
throwIfNothing Nothing tk msg = semError tk msg
throwIfNothing (Just a) _ _ = return a

-----------------------------------------------------------------------------------------------
-- Semantic analysers
-----------------------------------------------------------------------------------------------

-- | Convert a AST.Type into SemData.Type
astTypeToSemType :: Maybe AST.Type -> ParserMonad (Maybe Sem.Type)
astTypeToSemType ( Just (AST.Type tk typeMaybe) ) = do
    let entry_name = Sem.entry_name . fromJust

    entryMaybe <- PMonad.lookup (token tk)
    throwIfNothing entryMaybe tk "Type not found:"

    case typeMaybe of
        Nothing -> return $ Just $ Sem.Simple (entry_name entryMaybe)

        Just typeType -> do
            semTypeMaybe <- astTypeToSemType typeMaybe
            throwIfNothing semTypeMaybe tk "Semantic error:"
            return $ Just $ Sem.Compound (entry_name entryMaybe) (fromJust semTypeMaybe)

astTypeToSemType Nothing = return Nothing

-- | Checks if variable is declared, throws an error if it is not
analyzeVar :: Token -> ParserMonad Sem.Entry
analyzeVar tk = do
    let tkString = token tk
    entryMaybe <- PMonad.lookup tkString
    throwIfNothing entryMaybe tk "Variable not in scope:"
    return $ fromJust entryMaybe

-- | Analizes if field correspond to the type of the entry and throws an error if it is not
analyzeField :: Token -> Int -> ParserMonad Sem.Entry
analyzeField tk level = do
    let tkString = token tk
    entryMaybe <- PMonad.lookupField tkString level
    throwIfNothing entryMaybe tk ("Field not in type " ++ show tkString ++ ":")
    return $ fromJust entryMaybe

-- | Analizes LValue expression and return its type's entry
analyzeLValue :: AST.Expression -> ParserMonad Sem.Type
analyzeLValue (AST.IdExp (AST.Id tk)) = do
    entry <- analyzeVar tk
    let typeMaybe = Sem.entry_type entry
    throwIfNothing typeMaybe tk "Semantic error:"
    return $ fromJust typeMaybe

analyzeLValue (AST.IndexingExp lval _ bracket) = do
    lType <- analyzeLValue lval
    -- if it is not a melody, error
    case lType of
        Sem.Simple _ -> semError bracket "Expression is not a melody:"
        Sem.Compound _ innerType -> return innerType

analyzeLValue (AST.DereferenceExp lval) = analyzeLValue lval

analyzeLValue (AST.DotExp lval (AST.Id tk)) = do
    lType           <- analyzeLValue lval          -- Type of the left expression
    typeEntryMaybe  <- PMonad.typeEntry lType      -- Entry of the type
    throwIfNothing typeEntryMaybe tk "Type not found for left expression:"

    let levelMaybe  = Sem.entry_level $ fromJust typeEntryMaybe            -- Level opened by record
    throwIfNothing levelMaybe tk "Left expression is not a chord or legato:"
    
    fieldEntry <- analyzeField tk (fromJust levelMaybe)
    
    let typeMaybe = Sem.entry_type fieldEntry
    throwIfNothing typeMaybe tk "Semantic error:"
    
    return $ fromJust typeMaybe