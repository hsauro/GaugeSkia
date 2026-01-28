//
// Based on GDI+/VCL code written by Grégory Maël Nolann Malonn (January, 2026)
//

unit ufMain;

interface

uses
  System.SysUtils, System.Types, System.UIConsts, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, System.Skia, FMX.Skia, FMX.StdCtrls,
  FMX.Controls.Presentation,   FMX.Platform,
  FMX.FontManager;

type
  TfrmMain = class(TForm)
    SkPaintBox: TSkPaintBox;
    btnRandom: TButton;
    chkColorScale: TCheckBox;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure btnRandomClick(Sender: TObject);
    procedure SkPaintBoxDraw(ASender: TObject; const ACanvas: ISkCanvas; const
        ADest: TRectF; const AOpacity: Single);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
    FValue: Single;
    FTargetValue: Single;
    function ValueToAngle(AValue: Single): Single;
    procedure DrawGauge(ACanvas : ISkCanvas; const R: TRectF);

  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

Uses Math;

const
  GAUGE_ROTATION_DEG = -90.0;

  COL_GREEN  = TAlphaColor($FF00B400);
  COL_YELLOW = TAlphaColor($FFF0DC00);
  COL_ORANGE = TAlphaColor($FFFF8C00);
  COL_RED    = TAlphaColor($FFC81E1E);



function Lerp(a, b, t: Single): Single;
begin
  Result := a + (b - a) * t;
end;


function LerpColor(const C1, C2: TAlphaColor; T: Single): TAlphaColor;
var
  a1, r1, g1, b1: Byte;
  a2, r2, g2, b2: Byte;
begin
  a1 := TAlphaColorRec(C1).A;
  r1 := TAlphaColorRec(C1).R;
  g1 := TAlphaColorRec(C1).G;
  b1 := TAlphaColorRec(C1).B;

  a2 := TAlphaColorRec(C2).A;
  r2 := TAlphaColorRec(C2).R;
  g2 := TAlphaColorRec(C2).G;
  b2 := TAlphaColorRec(C2).B;

  Result :=
    (Round(Lerp(a1, a2, T)) shl 24) or
    (Round(Lerp(r1, r2, T)) shl 16) or
    (Round(Lerp(g1, g2, T)) shl 8)  or
     Round(Lerp(b1, b2, T));
end;


function ValueToColor(AValue: Single): TAlphaColor;
var v: Single;
begin
  AValue := EnsureRange(AValue, 0, 100);
  v := AValue / 100;

  if v <= 0.6 then
    Result := LerpColor(COL_GREEN, COL_YELLOW, v / 0.6)
  else if v <= 0.8 then
    Result := LerpColor(COL_YELLOW, COL_ORANGE, (v - 0.6) / 0.2)
  else
    Result := LerpColor(COL_ORANGE, COL_RED, (v - 0.8) / 0.2);
end;



function TfrmMain.ValueToAngle(AValue: Single): Single;
const
  BaseStart = -135.0;
  SweepAngle = 270.0;
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > 100 then
    AValue := 100;
  Result := BaseStart + (AValue / 100.0) * SweepAngle + GAUGE_ROTATION_DEG;
end;


procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FValue := 0.0;
  FTargetValue := 0.0;

  Timer1.Interval := 16;
  Timer1.Enabled := True;

  SkPaintBox.Redraw;
end;


procedure TfrmMain.btnRandomClick(Sender: TObject);
begin
  FTargetValue := Random * 100;
  SkPaintBox.Redraw;
end;


procedure TfrmMain.DrawGauge(ACanvas: ISkCanvas; const R: TRectF);
var
  cx, cy, radius: Single;
  startAngle, sweepAngle: Single;
  progressSweep: Single;
  LPaint: ISkPaint;
  arcRect: TRectF;
  i: Integer;
  tickAngle, tickRad: Single;
  x1, y1, x2, y2: Single;
  labelValue: string;
  fontSmall, fontValue: ISkFont;
  needleAngle, needleRad, nx, ny: Single;
  segCount, segIndex: Integer;
  segStart, segSweep: Single;
  segMidValue: Single;
  halfOverlapFrac, overlap, drawStart, drawSweep: Single;
  txt: string;
  bounds: TRectF;
  textX, textY: Single;
  metrics: TSkFontMetrics;
  fixedWidth: Single;
  LTypeface: ISkTypeface;
begin
  cx := (R.Left + R.Right) / 2;
  cy := (R.Top + R.Bottom) / 2;
  radius := Min(R.Width, R.Height) / 2 - 10;

  // was rectArc, is now arcRect
  arcRect := TRectF.Create(
    cx - radius, cy - radius,
    cx + radius, cy + radius
  );

  startAngle := -135.0 + GAUGE_ROTATION_DEG;
  sweepAngle := 270.0;
  progressSweep := (FValue / 100.0) * sweepAngle;

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Style := TSkPaintStyle.Stroke;
  LPaint.StrokeWidth := 18;
  LPaint.StrokeCap := TSkStrokeCap.Round;

  // Background arc
  LPaint.Color := MakeColor (230, 230, 230, 255);
  ACanvas.DrawArc(arcRect, startAngle, sweepAngle, False, LPaint);

  // Foreground arc
  if chkColorScale.IsChecked then
  begin
    segCount := 80;
    halfOverlapFrac := 0.12;

    for segIndex := 0 to segCount - 1 do
    begin
      segStart := startAngle + (segIndex / segCount) * progressSweep;
      segSweep := (1 / segCount) * progressSweep;
      if segSweep <= 0 then
        Break;

      overlap := segSweep * halfOverlapFrac;
      drawStart := segStart - overlap;
      drawSweep := segSweep + 2 * overlap;

      if drawStart < startAngle then
      begin
        drawSweep := drawSweep - (startAngle - drawStart);
        drawStart := startAngle;
      end;

      if (drawStart + drawSweep) > (startAngle + progressSweep) then
        drawSweep := (startAngle + progressSweep) - drawStart;

      if drawSweep <= 0 then
        Continue;

      segMidValue := ((segIndex + 0.5) / segCount) * (progressSweep / sweepAngle) * 100;

      LPaint.Color := ValueToColor(segMidValue);  // pen segment
      ACanvas.DrawArc(arcRect, drawStart, drawSweep, False, LPaint);
    end;
  end
  else
  begin
    LPaint.Color := ValueToColor(FValue);
    ACanvas.DrawArc(arcRect, startAngle, progressSweep, False, LPaint);
  end;

  // Ticks
  LPaint.StrokeWidth := 2;
  LPaint.Color := MakeColor(80, 80, 80, 255);

  for i := 0 to 10 do
  begin
    tickAngle := startAngle + i * (sweepAngle / 10);
    tickRad := DegToRad(tickAngle);

    x1 := cx + Cos(tickRad) * (radius - 9);
    y1 := cy + Sin(tickRad) * (radius - 9);
    x2 := cx + Cos(tickRad) * (radius - 25);
    y2 := cy + Sin(tickRad) * (radius - 25);

    ACanvas.DrawLine(x1, y1, x2, y2, LPaint);
  end;

  // Fonts
  fontSmall := TSkFont.Create(TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Normal), 12);
  fontValue := TSkFont.Create(TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Bold), 16);

  // Draw the text next to the tick marks
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := MakeColor (60, 60, 60, 255);
  for i := 0 to 10 do
  begin
    tickAngle := startAngle + i * (sweepAngle / 10);
    tickRad := DegToRad(tickAngle);

    labelValue := IntToStr(i * 10);
    ACanvas.DrawSimpleText(
      labelValue,
      cx + Cos(tickRad) * (radius - 40) - 8,
      cy + Sin(tickRad) * (radius - 40) + 8,
      fontSmall,
      LPaint
    );
  end;

  // Draw the needle
  needleAngle := ValueToAngle(FValue);
  needleRad := DegToRad(needleAngle);

  nx := cx + Cos(needleRad) * (radius - 55);
  ny := cy + Sin(needleRad) * (radius - 55);

  LPaint.Style := TSkPaintStyle.Stroke;
  LPaint.StrokeWidth := 4;
  LPaint.Color := MakeColor(200, 30, 30, 255);

  ACanvas.DrawLine(cx, cy, nx, ny, LPaint);

  // Draw the center dot
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := MakeColor(80, 80, 80, 255);
  ACanvas.DrawCircle(cx, cy, 6, LPaint);

  // Value text
  LPaint.Color := MakeColor (30, 30, 30, 255);

  // The following is to ensure a fixed centering of the text.
  // Don't include the % symbol here. This ensures that the number itself can be centered
  txt := FormatFloat('0.0', FValue);
  // Get the width of the text
  fontValue.MeasureText('100.0', bounds);
  fixedWidth := bounds.Width;

  fontValue.MeasureText(txt, bounds);
  // cx is the center x point of the paintbox
  textX := cx - fixedWidth / 2;

  // Vertical center relative to baseline
  textY := (cy + radius / 2.5) + bounds.Height / 2;

  ACanvas.DrawSimpleText(txt + ' %', textX, textY, fontValue, LPaint);
end;


procedure TfrmMain.SkPaintBoxDraw(ASender: TObject; const ACanvas: ISkCanvas;
    const ADest: TRectF; const AOpacity: Single);
var
  LPaint: ISkPaint;
  Margin, Size: Single;
  rc: TRectF;
begin
  ACanvas.Save; // Not really required here but generally good practice to include
  try
    ACanvas.Clear(TAlphaColors.White);

    margin := 10;

    rc := RectF(0, 0, SkPaintBox.Width, SkPaintBox.Height);

    size := Min(rc.Width, rc.Height) - 2 * margin;
    if size < 10 then
      size := 10;

    rc := RectF(
      (rc.Width - size) / 2,
      (rc.Height - size) / 2,
      (rc.Width + size) / 2,
      (rc.Height + size) / 2
    );

    DrawGauge(ACanvas, rc);
  finally
    // 2. Restore to the original state
    ACanvas.Restore;
  end;
end;


procedure TfrmMain.Timer1Timer(Sender: TObject);
const
  InterpFactor = 0.08;
begin
  if Abs(FValue - FTargetValue) > 0.001 then
  begin
    FValue := FValue + (FTargetValue - FValue) * InterpFactor;
    if Abs(FValue - FTargetValue) < 0.01 then
      FValue := FTargetValue;
    SkPaintBox.Redraw;
  end;
end;

end.
