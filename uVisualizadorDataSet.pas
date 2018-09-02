unit uVisualizadorDataSet;

interface

uses
  ToolsApi;

type
  TVisualizadorDataSets = class(TInterfacedObject, IOTAWizard, IOTAMenuWizard,
  IOTAThreadNotifier)
  private
    FProcessamentoFinalizado: boolean;

    { Assinaturas do IOTAWizard }
    function GetState: TWizardState;
    function GetIDString: string;
    function GetName: string;
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Execute;
    procedure Modified;

    {Assinaturas do IOTAMenuWizard}
    function GetMenuText: string;

    { Assinaturas do IOTAThreadNotifier }
    procedure EvaluteComplete(const ExprStr: string; const ResultStr: string;
      CanModify: Boolean; ResultAddress: Cardinal; ResultSize: Cardinal; ReturnCode: Integer);
    procedure ModifyComplete(const ExprStr: string; const ResultStr: string; ReturnCode: Integer);
    procedure ThreadNotify(Reason: TOTANotifyReason);

    {Assinaturas da TVisualizadorDataSets}
    procedure AbrirVisualizador;
    procedure Executar(Sender: TObject);

  public
    constructor Create;
  end;

procedure Register;

implementation

uses
  Vcl.Dialogs, System.SysUtils, System.IOUtils, Vcl.Forms,
  DataSnap.DBClient, Data.DB, Vcl.DBGrids, Vcl.Controls, Vcl.Menus;

procedure Register;
begin
  // Registra o Wizard
  RegisterPackageWizard(TVisualizadorDataSets.Create);
end;

function TVisualizadorDataSets.GetIDString: string;
begin
  // Texto de identifica��o do wizard
  result := 'Visualizador de DataSets';
end;

function TVisualizadorDataSets.GetMenuText: string;
begin
  // Texto que aparecer� no menu Help > Help Wizards
  result := 'Visualizador de DataSets';
end;

function TVisualizadorDataSets.GetName: string;
begin
  // Nome do wizard, exigido pela IDE
  result := 'Visualizador de DataSets';
end;

function TVisualizadorDataSets.GetState: TWizardState;
begin
  // Indica que o wizard est� habilitado na IDE
  result := [wsEnabled];
end;

procedure TVisualizadorDataSets.AbrirVisualizador;
var
  Formulario: TForm;
  DataSet: TClientDataSet;
  ArquivoDados: string;
  DataSource: TDataSource;
  DBGrid: TDBGrid;
begin
  Formulario := TForm.Create(nil);
  try
    Formulario.Caption := 'Visualizador de DataSets';
    Formulario.WindowState := wsMaximized;

    DataSet := TClientDataSet.Create(Formulario);

    // Arquivo tempor�rio gravado pelo visualizador
    ArquivoDados := System.IOUtils.TPath.GetTempPath + 'Dados.xml';

    DataSet.LoadFromFile(ArquivoDados);

    DataSource := TDataSource.Create(Formulario);
    DataSource.DataSet := DataSet;

    DBGrid := TDBGrid.Create(Formulario);
    DBGrid.Parent := Formulario;
    DBGrid.Align := alClient;
    DBGrid.DataSource := DataSource;

    Formulario.ShowModal;
  finally
    FreeAndNil(Formulario);
  end;
end;

procedure TVisualizadorDataSets.AfterSave;
begin

end;

procedure TVisualizadorDataSets.BeforeSave;
begin

end;

constructor TVisualizadorDataSets.Create;
var
  MainMenu: TMainMenu;
  MenuItem: TMenuItem;
begin
  MainMenu := (BorlandIDEServices as INTAServices).MainMenu;

  MenuItem := TMenuItem.Create(MainMenu);
  MenuItem.Caption := 'Visualizar DataSet';
  MenuItem.Name := 'VisualizarDataSet';
  MenuItem.OnClick := Executar;

  MainMenu.Items.Add(MenuItem);
end;

procedure TVisualizadorDataSets.Destroyed;
begin

end;

procedure TVisualizadorDataSets.Modified;
begin

end;

procedure TVisualizadorDataSets.EvaluteComplete(const ExprStr,
  ResultStr: string; CanModify: Boolean; ResultAddress, ResultSize: Cardinal;
  ReturnCode: Integer);
begin
  FProcessamentoFinalizado := True;
end;

procedure TVisualizadorDataSets.ModifyComplete(const ExprStr, ResultStr: string;
  ReturnCode: Integer);
begin

end;

procedure TVisualizadorDataSets.ThreadNotify(Reason: TOTANotifyReason);
begin

end;

procedure TVisualizadorDataSets.Executar(Sender: TObject);
begin
  Execute;
end;

procedure TVisualizadorDataSets.Execute;
var
  ArquivoDados: string;
  TextoSelecionado: string;
  Expressao: string;
  Thread: IOTAThread;
  Retorno: TOTAEvaluateResult;

  // Vari�veis para preencher os par�metros "out" do Evaluate
  CanModify: boolean;
  Endereco: UInt64;
  Tamanho: Cardinal;
  Resultado: Cardinal;

  IndiceNotifier: integer;
begin
  // O arquivo de dados ser� gravado na pasta tempor�ria do usu�rio
  ArquivoDados := System.IOUtils.TPath.GetTempPath + 'Dados.xml';

  // Obt�m o texto selecionado no editor
  TextoSelecionado := (BorlandIDEServices as IOTAEditorServices).TopView.GetBlock.Text;

  if TextoSelecionado = EmptyStr then
  begin
    ShowMessage('Selecione um DataSet antes de continuar.');
    Exit;
  end;

  // Monta a express�o que ser� avaliada pelo Debugger
  Expressao := Format('%s.SaveToFile(''%s'')', [TextoSelecionado, ArquivoDados]);

  // Obt�m a thread do servi�o de depura��o
  Thread := (BorlandIDEServices as IOTADebuggerServices).CurrentProcess.CurrentThread;

  // Solicita a avalia��o da express�o
  Retorno := Thread.Evaluate(Expressao, '', 0, CanModify, True, '', Endereco, Tamanho, Resultado);

  if Retorno = erDeferred then
  begin
    FProcessamentoFinalizado := False;

    // Adiciona um notificador, retornando um �ndice para que depois possamos remov�-lo
    IndiceNotifier := Thread.AddNotifier(Self);

    // Processa os eventos pendentes do depurador at� que EvaluteComplete seja chamado
    while not FProcessamentoFinalizado do
      (BorlandIDEServices as IOTADebuggerServices).ProcessDebugEvents;

    // Remove o notificador ap�s a conclus�o da avalia��o
    Thread.RemoveNotifier(IndiceNotifier);
  end;

  // Se a avalia��o foi realizada com sucesso, abre o formul�rio para visualiza��o dos dados
  if not (Retorno in [erError, erBusy]) then
    AbrirVisualizador;
end;

end.
