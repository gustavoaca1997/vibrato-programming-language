module Backend.TAC.TAC where

import qualified Semantic.Data as Sem
import qualified AST
import Data.Maybe

class SymEntryCompatible a where
  getSymID :: a -> String

data (SymEntryCompatible a) => ThreeAddressCode a b = ThreeAddressCode
  { tacOperand :: Operation,
    tacLvalue  :: Maybe (Operand a b),
    tacRvalue1 :: Maybe (Operand a b),
    tacRvalue2 :: Maybe (Operand a b)
  }
  deriving (Eq)

instance (SymEntryCompatible a, Show a, Show b) => Show (ThreeAddressCode a b) where
  show (ThreeAddressCode Assign (Just x) (Just y) _) = show x ++ " = " ++ show y
  show (ThreeAddressCode Add (Just x) (Just y) (Just z)) = show x ++ " = " ++ show y ++ " + " ++ show z
  show (ThreeAddressCode Minus (Just x) (Just y) Nothing) = show x ++ " = -" ++ show y 
  show (ThreeAddressCode Sub (Just x) (Just y) (Just z)) = show x ++ " = " ++ show y ++ " - " ++ show z
  show (ThreeAddressCode Mult (Just x) (Just y) (Just z)) = show x ++ " = " ++ show y ++ " * " ++ show z
  show (ThreeAddressCode Div (Just x) (Just y) (Just z)) = show x ++ " = " ++ show y ++ " / " ++ show z
  show (ThreeAddressCode (Cast _ toType) (Just x) (Just y) _) = show x ++ " = " ++ toType ++ "(" ++ show y ++ ")"
  show tac = show (tacLvalue tac) ++ " = " ++ show (tacRvalue1 tac) ++ " (?) " ++ show (tacRvalue2 tac)

type Instruction = ThreeAddressCode Entry AST.Expression
type Value = Operand Entry AST.Expression

data (SymEntryCompatible a) => Operand a b = 
  Variable a | 
  Constant b | 
  Label Int
  deriving (Eq)

instance (SymEntryCompatible a, Show a, Show b) => Show (Operand a b) where
  show (Variable x) = show x
  show (Constant c) = show c
  show (Label l) = show l

data Operation =
    Assign        |
    -- Arithmetic
    -- | Addition
    Add            |
    -- | Substraction
    Sub           |
    -- | Unary minus
    Minus           |
    -- | Multiplication
    Mult          |
    -- | Division
    Div           |
    -- | Modulus
    Mod          |

    -- Logical
    -- | Logical and
    And               |
    -- | Logical or
    Or               |
    -- | Logical not
    Not             |

    -- Comparators
    -- | Greater than
    Gt           |
    -- | Greater than or equal
    Gte        |
    -- | Less than
    Lt           |
    -- | Less than or equal
    Lte        |
    -- | Equal
    Eq           |
    -- | Not equal
    Neq         |

    -- Jumping
    -- | goto <label>
    GoTo        |
    -- | if <var> goto <label>
    If          |
    -- | if ~<var> goto <label>
    IfFalse     |
    -- | New label
    NewLabel       |

    -- Calling functions
    -- | Define a parameter
    Param       |
    -- | Call function
    Call        |

    -- Array operators
    -- | x=y[i]
    Get         |
    -- | x[i]=y
    Set         |

    -- Pointer operations
    -- | x=&y
    Ref         |
    -- | x=*y
    Deref       |

    Cast String String
    deriving (Eq, Show)


data Entry = Entry {
    entry_name  :: String,
    entry_type  :: AST.Type,
    entry_scope :: Maybe Int
} deriving (Eq)

instance Show Entry where
  show = entry_name

instance SymEntryCompatible Entry where
    getSymID = entry_name

entryToTAC :: Sem.Entry -> Entry
entryToTAC e = Entry (Sem.entry_name e) (fromJust $ Sem.entry_type e) $ Just $ Sem.entry_scope e