  // Shared A4 protocol template, embedded at compile time. FPReport owns
  // text metrics, group repetition and all page breaks, including row continuations.
  Report.TwoPass := FSnapshot.Options.ShowFooter;
  Report.Title := FTitle;
  P := TFPReportPage.Create(Report);
  P.PageSize.PaperName := 'A4';
  if FSnapshot.Options.Landscape then P.Orientation := poLandscape;
  P.Margins.Left := 10;
  P.Margins.Right := 10;
  P.Margins.Top := 10;
  P.Margins.Bottom := 10;
  P.Font.Name := ReportRegularFont;
  P.Font.Size := 8;
  P.Data := FData;
  if P.Orientation = poLandscape then W := P.PageSize.Height - 20
  else
    W := P.PageSize.Width - 20;
  if FSnapshot.Options.ShowHeader then
  begin
    Header := TFPReportPageHeaderBand.Create(P);
    Header.Layout.Height := 7;
    Header.StretchMode := smActualHeightStretchOnly;
    M := Memo(Header, '[' + FData.Name + '.heading]', 0, 0, W, 6);
    M.StretchMode := smActualHeight;
    M.Font.Color := clGray;
    M.Frame.Lines := [flBottom];
    M.Frame.Color := clGray;
  end;
  Group := TFPReportGroupHeaderBand.Create(P);
  Group.Data := FData;
  Group.GroupCondition := FData.Name + '.groupkey';
  Group.Layout.Height := 8;
  if FSnapshot.Options.HideCategories then Group.Layout.Height := 0;
  Group.OnBeforePrint := @ResultHeadingBeforePrint;
  Group.VisibleExpr := FData.Name + '.groupkey <> ' + QuotedStr('');
  Group.StretchMode := smActualHeightStretchOnly;
  Group.ReprintedHeader := [rsPage];
  Group.OverflowWithFirstDataBand := [rsPage];
  if not FSnapshot.Options.HideCategories then
  begin
    M := Memo(Group, '[' + FData.Name + '.categorycaption]', 0, 2, W, 6, True);
    M.Font.Size := CategoryTitleFontSize;
    M.StretchMode := smActualHeight;
  end;
  ColumnsHeader := TFPReportChildBand.Create(P);
  ColumnsHeader.Layout.Height := HeaderHeight;
  Group.ChildBand := ColumnsHeader;
  ColumnsHeader.OnBeforePrint := @ResultHeadingBeforePrint;
  ColumnsHeader.VisibleExpr := Group.VisibleExpr;
  X := 0;
  for C := 0 to High(FWidths) do
  begin
    if FWidths[C] <= 0 then Continue;
    if (FSnapshot.Columns[C].StageIndex > 0) and
      ((ProtocolGroupEnd(FSnapshot, C) > C) or
      ((C > 0) and (FSnapshot.Columns[C - 1].StageIndex =
      FSnapshot.Columns[C].StageIndex))) then
    begin
      if (C = 0) or (FSnapshot.Columns[C - 1].StageIndex <>
        FSnapshot.Columns[C].StageIndex) then
      begin
        LastColumn := ProtocolGroupEnd(FSnapshot, C);
        GroupWidth := 0;
        for K := C to LastColumn do GroupWidth := GroupWidth + FWidths[K];
        ColumnMemo(ColumnsHeader, FSnapshot.Columns[C].GroupCaption,
          X, 0, GroupWidth, GroupHeight - 1, FTableFont);
      end;
      M := ColumnMemo(ColumnsHeader, FSnapshot.Columns[C].Caption,
        X, GroupHeight, FWidths[C], LeafHeight - 1, FTableFont);
    end
    else
      M := ColumnMemo(ColumnsHeader, ProtocolColumnCaption(FSnapshot, C),
        X, 0, FWidths[C], HeaderHeight - 1, FTableFont);
    M.Frame.Lines := [flBottom];
    M.Frame.Color := clBlack;
    X := X + FWidths[C];
  end;
  Body := TFPReportDataBand.Create(P);
  Body.Data := FData;
  Body.Layout.Height := 5;
  X := 0;
  for C := 0 to High(FWidths) do
  begin
    if FWidths[C] <= 0 then Continue;
    M := Memo(Body, '[' + FData.Name + '.c' + IntToStr(Ord(C)) + ']',
      X, 0, FWidths[C], 5);
    M.Font.Size := FTableFont;
    M.TextAlignment.LeftMargin := FTableFont / 8;
    M.TextAlignment.RightMargin := FTableFont / 8;
    X := X + FWidths[C];
  end;
  if FSnapshot.Options.ShowFooter then
  begin
    Footer := TFPReportPageFooterBand.Create(P);
    Footer.Layout.Height := 8;
    Memo(Footer, '[' + FData.Name + '.stamp]', 0, 2, W / 2, 6);
    M := Memo(Footer, FSnapshot.Labels.Page + ' [PageNo] ' +
      FSnapshot.Labels.OfPages + ' [PageCount]', W / 2, 2, W / 2, 6);
    M.TextAlignment.Horizontal := taRightJustified;
  end;

  DataHeader := AddTemplateBlock(P, FSnapshot.Template.Header, True, W);
  if FSnapshot.Options.ShowHeadings then
  begin
    RaceHeader := TFPReportChildBand.Create(P);
    DataHeader.ChildBand := RaceHeader;
    RaceHeader.Layout.Height := 7;
    RaceHeader.StretchMode := smActualHeightStretchOnly;
    M := Memo(RaceHeader, '[' + FData.Name + '.race]', 0, 0, W, 6, True);
    M.Font.Size := CompetitionTitleFontSize;
    M.StretchMode := smActualHeight;
    ProtocolHeading := TFPReportChildBand.Create(P);
    RaceHeader.ChildBand := ProtocolHeading;
    ProtocolHeading.Layout.Height := 7;
    ProtocolHeading.StretchMode := smActualHeightStretchOnly;
    M := Memo(ProtocolHeading, '[' + FData.Name + '.heading]', 0, 0, W, 6, True);
    M.StretchMode := smActualHeight;
  end;
  AddTemplateBlock(P, FSnapshot.Template.Footer, False, W);
