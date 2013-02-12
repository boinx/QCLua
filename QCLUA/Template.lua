-- availiable types are
--  QC_BOOLEAN
--  QC_NUMBER
--  QC_STRING
--  QC_STRUCT
--  QC_INDEX

-- an input can be defined with inNAME = TYPE
inA = QC_NUMBER
inB = QC_NUMBER

-- an output can be defined with outNAME = TYPE
outResult = QC_NUMBER

-- special variables
--  patchtime contains the time of the patch

-- define a main function without paramters
-- main() will be called each time the code or inputs are changed
main = function()

	outResult = inA + inB

end
