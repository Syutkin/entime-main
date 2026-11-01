unit ReportPreview;
{$mode objfpc}{$H+}
interface

uses Forms, ExtCtrls, fpreportlclexport;

procedure ResizeReportPreview(Renderer: TFPReportExportCanvas;
  ZoomIndex: integer; Scroll: TScrollBox; Canvas: TPaintBox);
procedure PaintReportPreview(Renderer: TFPReportExportCanvas; Canvas: TPaintBox);

implementation

uses Math, Graphics;

procedure ResizeReportPreview(Renderer: TFPReportExportCanvas;
  ZoomIndex: integer; Scroll: TScrollBox; Canvas: TPaintBox);
const
  Zooms: array[1..6] of double = (0.5, 0.75, 1, 1.25, 1.5, 2);
var
  W, H: integer;
begin
  if Renderer = nil then Exit;
  if ZoomIndex <= 0 then
  begin
    Renderer.Zoom := 1;
    Renderer.GetCurrentPageRenderSize(W, H);
    // Stable width regardless of whether the native scrollbar is visible.
    if W > 0 then Renderer.Zoom := Max(0.1, (Scroll.VertScrollBar.ClientSizeWithBar - 24) / W);
  end
  else
    Renderer.Zoom := Zooms[EnsureRange(ZoomIndex, 1, 6)];
  // Document canvas dimensions supplied by FPReport, not form layout.
  Renderer.GetCurrentPageRenderSize(W, H);
  Canvas.SetBounds(0, 0, W, H);
  Canvas.Invalidate;
end;

procedure PaintReportPreview(Renderer: TFPReportExportCanvas; Canvas: TPaintBox);
begin
  Canvas.Canvas.Brush.Color := clWhite;
  Canvas.Canvas.FillRect(Canvas.ClientRect);
  if Renderer = nil then Exit;
  Renderer.Canvas := Canvas.Canvas;
  Renderer.RenderCurrentPage;
end;

end.
