unit MainForm;

{$B-}
{$I Directives.inc}

interface

uses
  {$IFDEF DELPHI_XE7}WinApi.Windows, WinApi.Messages, {$ELSE}Windows, Messages,
  {$ENDIF}SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, Dialogs, Parser,
  ParseTypes, ValueTypes;

type
  TMain = class(TForm)
    Bevel: TBevel;
    bExecute: TButton;
    eFormula: TEdit;
    laHint: TLabel;
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure bExecuteClick(Sender: TObject);
  private
    FLargestHandle: Integer;
    FParser: TParser;
  protected
    // We have the new function "Largest" which returns the largest parameter:
    function Largest(const AFunction: PFunction; const AType: PType;
      const ParameterArray: TParameterArray): TValue; virtual;
  public
    property Parser: TParser read FParser write FParser;

    // Handle of the new funtion is needed for its registration and
    // further managing:
    property LargestHandle: Integer read FLargestHandle;
  end;

var
  Main: TMain;

implementation

uses
  ValueUtils;

{$R *.dfm}

procedure TMain.FormCreate(Sender: TObject);
begin
  // Create a new instance of TMathParser object:

  FParser := TMathParser.Create(Self);
  {
    function AddFunction(const AName: string; var Handle: Integer;
      Kind: TFunctionKind; Method: TFunctionMethod; Optimizable: Boolean;
      ReturnType: TValueType): Boolean;

    - AName: the new function name;
    - Handle: the new function identifier is needed for function managing;

        TFunctionKind = (fkHandle, fkMethod);

    - Kind specifies the way of function result returning. If Kind is fkHandle then
      the function result is returned by user-defined event handler of
      TParser.OnFunctionEvent. If Kind is fkMethod then the result is in the
      user-defied method, declared in TFunctionMethod structure - see below;

    - Method: the structure completely describes the function behavior;

        TMethodType = (mtEmpty, mtParameterless, mtSingleParameter, mtDoubleParameter, mtParameterArray, mtVariable);

        TParameterlessMethod = function(const AFunction: PFunction; const AType: PType): TValue of object;
        TSingleParameterMethod = function(const AFunction: PFunction; const AType: PType;
          const Value: TValue): TValue of object;
        TDoubleParameterMethod = function(const AFunction: PFunction; const AType: PType;
          const LValue, RValue: TValue): TValue of object;
        TParameterArrayMethod = function(const AFunction: PFunction; const AType: PType;
          const ParameterArray: TParameterArray): TValue of object;

        TFunctionMethod = record
          Parameter: TFunctionParameter;
          MethodType: TMethodType;
          Variable: TFunctionVariable;
          case Byte of
            0: (AMethod: TParameterlessMethod);
            1: (BMethod: TSingleParameterMethod);
            2: (CMethod: TDoubleParameterMethod);
            3: (DMethod: TParameterArrayMethod);
        end;

        - TFunctionMethod.Parameter: the structure completely describes needed
          parameters for the function;

          From the logical point of view - there are only five types of function,
          but from the technical poit of view - there is one more function type -
          a variable. Below is the list of all possible function types (including
          variable):

            1. A function which requires no parameters. Such function simply returns
            some result. For example, True (returns True value) function does not
            require any expression. It behaves itself like variable.

              In this case TFunctionMethod.MethodType is mtParameterless and the
              user-defined function is of TParameterlessMethod type.

            2. A function which require parameter before itself.
            For example, ! function (returns factorial of an expression) require
            expression before itself.

              In this case TFunctionMethod.MethodType is mtSingleParameter and
              the user-defined function is of TSingleParameterMethod type.

            3. A function which require parameter after itself.
            For example, Int function (returns the integer part of a number) requires
            expression after itself.

              In this case TFunctionMethod.MethodType is mtSingleParameter and
              the user-defined function is of TSingleParameterMethod type.

            4. A function which requires both parameters � before and after itself.
            For example, ^ function (raises expression to any power) requires both
            expressions � before and after itself.

              In this case TFunctionMethod.MethodType is mtDoubleParameter and
              the user-defined function is of TDoubleParameterMethod type.

            5. A function which requires a number of parameters, following right
            after the function and enclosed in round brackets. For example, Sum
            function (returns the sum of all input parameters) requires one or more
            parameters.

              In this case TFunctionMethod.MethodType is mtParameterArray and the
              user-defined function is of TParameterArrayMethod type.

            6. A function which simply refers to the variable. The reference is
            in TFunctionVariable structure.

              In this case TFunctionMethod.MethodType is mtVariable and the function
              result is in the TFunctionMethod.Variable.

        - TFunctionMethod.MethodType: indicates the type of function;
        - TFunctionMethod.Variable: keeps the variable in case when TFunctionMethod.Method
          is mtVariable.

        "FunctionMethod" is the name of several overloaded functions. Each function
        fills the TFunctionMethod structure and differs by the function type it
        describes (see the list above). These functions fill only the necessary
        fields, according to the passed parameters and may require the following
        parameters:
          - Method: function method of one of the following types:
              - TParameterlessMethod;
              - TSingleParameterMethod;
              - TDoubleParameterMethod;
              - TParameterArrayMethod.
          - LParameter: defines if the function requires parameter from left;
          - RParameter: defines if the function requires parameter from right.

    - Optimizable: defines wheather or not the function may be simplified during
      the formula optimization process;
    - ReturnType of TValueType defines function returning type.
  }

  FParser.AddFunction('Largest', FLargestHandle, fkMethod, MakeFunctionMethod(Largest, 1),
    True, vtDouble);

  {
    MakeFunctionMethod here needs two parameters:
      - Method: LargestMethod (function method).
      - Count: input parameter count for the function, this parameter is only
        needed within the function method (LargestMethod) for check purpose.
        Since the LargestMethod is the function with the unlimited parameter
        count, "Count" paremeter needs to be set to any value greater than zero.
  }
end;

function TMain.Largest(const AFunction: PFunction; const AType: PType;
  const ParameterArray: TParameterArray): TValue;
var
  I: Integer;
  Value: Double;
begin
  {
    All input parameters and the Result are kept in TValue structure. TValue structre
    allows to decribe a variable which may have one of the following types:
      - Byte
      - Shortint
      - Word
      - Smallint
      - Longword
      - Integer
      - Int64
      - Single
      - Double
      - WordRec
      - LongRec
      - Int64Rec

    TValueType = (vtUnknown, vtByte, vtShortint, vtWord, vtSmallint, vtLongword,
      vtInteger, vtInt64, vtSingle, vtDouble);
    TValue = record
      ValueType: TValueType;
      case Byte of
        0: (ByteArray: array[0..7] of Byte);
        1: (Unsigned8: Byte);
        2: (Signed8: Shortint);
        3: (Unsigned16: Word);
        4: (Signed16: Smallint);
        5: (Unsigned32: Longword);
        6: (Signed32: Integer);
        7: (Signed64: Int64);
        8: (Float32: Single);
        9: (Float64: Double);
        10: (WordRec: WordRec);
        11: (LongRec: LongRec);
        12: (Int64Rec: Int64Rec);
    end;

    TValue.ValueType field defines the variable type.

    To simplify the sample we decide that the returing value is of Double type.
    To assign the value of Double type to the variable of TValueType we use
    AssignDouble function from ValueUtils unit.
  }

  AssignDouble(Result, 0);
  for I := Low(ParameterArray) to High(ParameterArray) do
  begin
    Value := Convert(ParameterArray[I].Value, vtDouble).Float64;
    if Result.Float64 < Value then AssignDouble(Result, Value);
  end;

  {
    Within this method we are able to compare the actual input parameter count -
    "Length(ParameterArray)" with the paremeter count specified when making this
    function - "AFunction.Method.Parameter.Count"
  }
end;

procedure TMain.bExecuteClick(Sender: TObject);
var
  Script: TScript;
begin
  // Compile the formula to the Script:
  FParser.StringToScript(eFormula.Text, Script);
  try

    {
      Execute method returns pointer to the TValue type. To convert TValue to
      string we use ValueToText method from ValueUtils unit:
    }
    ShowMessage( ValueToText( FParser.Execute(Script)^ ) );

  finally
    Script := nil;
  end;
end;

end.