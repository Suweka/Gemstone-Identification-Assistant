# Builds the report and user manual (.docx + .pdf) from the HTML sources using Microsoft Word.
# Usage (PowerShell, from any folder):  & "<path>\docs\src\build_docs.ps1" -Data <folder with generated fragments>
param([string]$Data, [string]$Log = '')

function Step([string]$m) { if ($Log) { Add-Content $Log ("{0:HH:mm:ss} {1}" -f (Get-Date), $m) } }

$ErrorActionPreference = 'Stop'
$src   = Split-Path -Parent $MyInvocation.MyCommand.Path
$docs  = Split-Path -Parent $src
$img   = Join-Path $docs 'img'
$build = Join-Path $src 'build'
New-Item -ItemType Directory -Force $build | Out-Null

function HtmlEscape([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

$imgUrl = 'file:///' + ($img -replace '\\', '/')
$frag = @{
    '{{t_rules}}'   = [IO.File]::ReadAllText((Join-Path $Data 't_rules.html'))
    '{{t_facts}}'   = [IO.File]::ReadAllText((Join-Path $Data 't_facts.html'))
    '{{t_cf}}'      = [IO.File]::ReadAllText((Join-Path $Data 't_cf.html'))
    '{{t_gemfacts}}' = [IO.File]::ReadAllText((Join-Path $Data 't_gemfacts.html'))
    '{{tests_out}}' = HtmlEscape ([IO.File]::ReadAllText((Join-Path $Data 'tests_out.txt')).Trim())
    '{{console}}'   = HtmlEscape ([IO.File]::ReadAllText((Join-Path $Data 'console_consult.txt')).Trim())
}

$word = New-Object -ComObject Word.Application
$word.Visible = $true      # hidden Word hangs on save after the TOC is inserted
$word.DisplayAlerts = 0
try {
    foreach ($pair in @(@('report.html', 'Gemstone_Identification_Assistant_Report'),
                        @('manual.html', 'Gemstone_Identification_Assistant_User_Manual'))) {
        $html = [IO.File]::ReadAllText((Join-Path $src $pair[0]))
        foreach ($k in $frag.Keys) { $html = $html.Replace($k, $frag[$k]) }
        $html = $html.Replace('{{IMG}}', $imgUrl)          # last: fragments contain it too
        # give every picture an explicit height so Word keeps its aspect ratio (max 820 px tall)
        Add-Type -AssemblyName System.Drawing
        $html = [regex]::Replace($html, '<img src="([^"]+)" width="([0-9]+)">', [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            $path = ($m.Groups[1].Value -replace '^file:///', '') -replace '/', '\'
            $im = [Drawing.Image]::FromFile($path)
            $w = [int]$m.Groups[2].Value
            $h = [int]($w * $im.Height / $im.Width)
            if ($h -gt 820) { $w = [int]($w * 820 / $h); $h = 820 }
            $im.Dispose()
            '<img src="' + $m.Groups[1].Value + '" width="' + $w + '" height="' + $h + '">'
        })
        $tmp = Join-Path $build $pair[0]
        [IO.File]::WriteAllText($tmp, $html, (New-Object Text.UTF8Encoding $true))

        Step "open $tmp"
        $doc = $word.Documents.Open($tmp, $false, $false, $false)
        Step "opened"
        $doc.ActiveWindow.View.Type = 3                     # print layout

        # A4, 2.54 cm margins
        $ps = $doc.PageSetup
        $ps.PaperSize = 7                                   # wdPaperA4
        $ps.TopMargin = 72; $ps.BottomMargin = 72; $ps.LeftMargin = 72; $ps.RightMargin = 72

        Step "page setup done"
        # embed linked pictures in the document
        foreach ($s in @($doc.InlineShapes)) {
            if ($s.LinkFormat -ne $null) {
                $s.LinkFormat.SavePictureWithDocument = $true
                $s.LinkFormat.BreakLink()
            }
        }

        Step "pictures embedded"
        # page numbers in the footer (not on the title page)
        $sec = $doc.Sections.Item(1)
        $sec.PageSetup.DifferentFirstPageHeaderFooter = -1
        [void]$sec.Footers.Item(1).PageNumbers.Add(1, $false)   # centre, not on first page
        $ft = $sec.Footers.Item(1).Range.Font
        $ft.Name = 'Times New Roman'; $ft.Size = 12; $ft.Color = -16777216
        # headings: Times New Roman, black (Word's heading styles are blue by default)
        foreach ($st in -2, -3, -4) {
            $doc.Styles.Item($st).Font.Name = 'Times New Roman'
            $doc.Styles.Item($st).Font.Color = -16777216
        }
        # keep each code block on one page: every code line stays with the next
        # (Word ignores this for blocks longer than a page, e.g. the appendices)
        try {
            $pre = $doc.Styles.Item('HTML Preformatted')
            $pre.ParagraphFormat.KeepWithNext = -1
            $pre.ParagraphFormat.KeepTogether = -1
        } catch { }
        # table header rows repeat on each page and never sit alone at a page end
        foreach ($t in @($doc.Tables)) {
            try {
                $t.Rows.Item(1).HeadingFormat = -1
                $t.Rows.Item(1).Range.ParagraphFormat.KeepWithNext = -1
            } catch { }
        }
        # hyperlinks black too
        $doc.Styles.Item(-86).Font.Color = -16777216

        Step "page numbers added"
        # table of contents at the [[TOC]] marker
        $rng = $doc.Content
        $find = $rng.Find
        if ($find.Execute('[[TOC]]')) {
            $rng.Text = ''
            [void]$doc.TablesOfContents.Add($rng, $true, 1, 2)
            foreach ($st in -20, -21, -22) {                # built-in styles TOC 1-3
                $doc.Styles.Item($st).Font.Name = 'Times New Roman'
                $doc.Styles.Item($st).Font.Size = 12
                $doc.Styles.Item($st).Font.Color = -16777216 # automatic (black)
                $doc.Styles.Item($st).ParagraphFormat.LineSpacingRule = 1   # 1.5 lines
            }
            $doc.TablesOfContents.Item(1).Update()
        }

        $final = Join-Path $docs ($pair[1] + '.docx')
        $docx = Join-Path $env:TEMP ($pair[1] + '.docx')
        $pdf  = Join-Path $env:TEMP ($pair[1] + '.pdf')
        Step "toc done"
        $doc.SaveAs2([string]$docx, 16)                   # wdFormatDocumentDefault
        Step "saved docx"
        Step "exported pdf"                  # wdExportFormatPDF
        $pages = $doc.ComputeStatistics(2)                  # wdStatisticPages
        $doc.Close($false)
        Copy-Item $docx $final -Force
        "$($pair[1]): $pages pages"
        $d2 = $word.Documents.Open([string]$docx)
        $d2.SaveAs2([string]$pdf, 17)                       # wdFormatPDF
        $d2.Close($false)
        Copy-Item $pdf (Join-Path $build ($pair[1] + '.pdf')) -Force
        Copy-Item $pdf (Join-Path $docs ($pair[1] + '.pdf')) -Force
    }
}
finally {
    $word.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}
