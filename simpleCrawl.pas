program SimpleWebCrawler;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fphttpclient,
  StrUtils,
  opensslsockets;

const
  OutputLinksFile = 'links.txt';
  OutputImagesFile = 'images.txt';

  function GetPageContent(const URL: string): string;
  var
    HTTPClient: TFPHTTPClient;
  begin
    Result := '';
    HTTPClient := TFPHTTPClient.Create(nil);
    try
      try
        Result := HTTPClient.Get(URL);
      except
        on E: Exception do
          WriteLn('Error fetching URL ', URL, ': ', E.Message);
      end;
    finally
      HTTPClient.Free;
    end;
  end;

  function GetBaseURL(const URL: string): string;
  var
    Protocol, Host, Path: string;
    PosSlash: integer;
  begin
    // Extract protocol (http or https)
    if Pos('https://', URL) = 1 then
      Protocol := 'https://'
    else if Pos('http://', URL) = 1 then
      Protocol := 'http://'
    else
      Exit('');

    // Extract host and path
    Path := Copy(URL, Length(Protocol) + 1, MaxInt);
    PosSlash := Pos('/', Path);
    if PosSlash > 0 then
      Host := Copy(Path, 1, PosSlash - 1)
    else
      Host := Path;

    Result := Protocol + Host;
  end;

  function ResolveAbsoluteURL(const BaseURL, RelativeURL: string): string;
  begin
    if (Pos('http://', RelativeURL) = 1) or (Pos('https://', RelativeURL) = 1) then
      Result := RelativeURL // Already absolute
    else if (RelativeURL <> '') and (RelativeURL[1] = '/') then
      Result := BaseURL + RelativeURL // Root-relative path
    else if (Pos('./', RelativeURL) = 1) then
      Result := BaseURL + Copy(RelativeURL, 2, MaxInt) // Handle ./ prefix
    else
      Result := BaseURL + '/' + RelativeURL; // Relative path
  end;

  function ExtractLinks(const HTML, BaseURL: string): TStringArray;
  var
    Lines: TStringArray;
    I: integer;
    Line, Link: string;
    PosStart, PosEnd: integer;
    Links: TStringArray;
    LinkCount: integer;
  begin
    SetLength(Links, 0);
    LinkCount := 0;
    Lines := HTML.Split(['<a ', '<A ']);
    for I := 1 to High(Lines) do
    begin
      Line := Lines[I];
      PosStart := Pos('href="', Line);
      if PosStart = 0 then
        PosStart := Pos('href=''', Line);
      if PosStart > 0 then
      begin
        PosStart := PosStart + 6;
        PosEnd := Pos('"', Line, PosStart);
        if PosEnd = 0 then
          PosEnd := Pos('''', Line, PosStart);
        if PosEnd > PosStart then
        begin
          Link := Copy(Line, PosStart, PosEnd - PosStart);
          if (Link <> '') and (Link[1] <> '#') then
          begin
            Inc(LinkCount);
            SetLength(Links, LinkCount);
            Links[LinkCount - 1] := ResolveAbsoluteURL(BaseURL, Link);
          end;
        end;
      end;
    end;
    Result := Links;
  end;

  function ExtractImages(const HTML, BaseURL: string): TStringArray;
  var
    Lines: TStringArray;
    I: integer;
    Line, Img: string;
    PosStart, PosEnd: integer;
    Images: TStringArray;
    ImgCount: integer;
  begin
    SetLength(Images, 0);
    ImgCount := 0;
    Lines := HTML.Split(['<img ', '<IMG ']);
    for I := 1 to High(Lines) do
    begin
      Line := Lines[I];
      PosStart := Pos('src="', Line);
      if PosStart = 0 then
        PosStart := Pos('src=''', Line);
      if PosStart > 0 then
      begin
        PosStart := PosStart + 5;
        PosEnd := Pos('"', Line, PosStart);
        if PosEnd = 0 then
          PosEnd := Pos('''', Line, PosStart);
        if PosEnd > PosStart then
        begin
          Img := Copy(Line, PosStart, PosEnd - PosStart);
          if Img <> '' then
          begin
            Inc(ImgCount);
            SetLength(Images, ImgCount);
            Images[ImgCount - 1] := ResolveAbsoluteURL(BaseURL, Img);
          end;
        end;
      end;
    end;
    Result := Images;
  end;

  procedure SaveToFile(const FileName: string; const Items: TStringArray);
  var
    F: TextFile;
    I: integer;
  begin
    AssignFile(F, FileName);
    try
      Rewrite(F);
      for I := 0 to High(Items) do
        WriteLn(F, Items[I]);
    finally
      CloseFile(F);
    end;
  end;

var
  URL, BaseURL: string;
  HTML: string;
  Links, Images: TStringArray;
begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: ', 'SimpleCrawl', ' <URL>');
    Halt(1);
  end;

  URL := ParamStr(1);
  WriteLn('Crawling: ', URL);

  BaseURL := GetBaseURL(URL);
  if BaseURL = '' then
  begin
    WriteLn('Invalid URL format: ', URL);
    Halt(1);
  end;

  HTML := GetPageContent(URL);
  if HTML = '' then
  begin
    WriteLn('Failed to retrieve page content.');
    Halt(1);
  end;

  Links := ExtractLinks(HTML, BaseURL);
  Images := ExtractImages(HTML, BaseURL);

  if Length(Links) > 0 then
  begin
    WriteLn('Saving ', Length(Links), ' links to ', OutputLinksFile);
    SaveToFile(OutputLinksFile, Links);
  end
  else
    WriteLn('No links found.');

  if Length(Images) > 0 then
  begin
    WriteLn('Saving ', Length(Images), ' image URLs to ', OutputImagesFile);
    SaveToFile(OutputImagesFile, Images);
  end
  else
    WriteLn('No images found.');

  WriteLn('Crawling complete.');
end.
