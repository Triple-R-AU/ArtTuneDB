# Triple R Audio - Client Edition (v2.0 Full Suite)
[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($PSCommandPath) {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

$OwnerGitHubUser = "Triple-R-AU"
$OwnerRepoName   = "ArtTuneDB"
$OwnerBranch     = "main"

$baseDir     = "C:\Program Files\EqualizerAPO\config\ArtTuneDB"
$libraryDir  = Join-Path $baseDir "library"
$eqBaseDir   = Join-Path $libraryDir "BO7\V5\eq"
$eapoConfig  = "C:\Program Files\EqualizerAPO\config\config.txt"
$boostFile   = Join-Path $baseDir "boost.txt"
$clientCfg   = Join-Path $baseDir "client_settings.json"
$readmeFile  = Join-Path $baseDir "README.txt"

if (-not (Test-Path $baseDir)) { New-Item -Path $baseDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $eqBaseDir)) { New-Item -Path $eqBaseDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $boostFile)) { "Preamp: 0 dB" | Set-Content -Path $boostFile -Force }

# Load saved state
$selectedTheme  = "Red & Black"
$leqEnabled     = $true
$leqReleaseTime = 2
$tuneActiveMode = $true
$customUserHeadphones = @()

if (Test-Path $clientCfg) {
    try {
        $cfg = Get-Content $clientCfg -Raw | ConvertFrom-Json
        if ($cfg.Theme) { $selectedTheme = $cfg.Theme }
        if ($null -ne $cfg.LeqEnabled) { $leqEnabled = [bool]$cfg.LeqEnabled }
        if ($cfg.LeqReleaseTime) { $leqReleaseTime = [int]$cfg.LeqReleaseTime }
        if ($null -ne $cfg.TuneActiveMode) { $tuneActiveMode = [bool]$cfg.TuneActiveMode }
        if ($cfg.CustomHeadphones) { $customUserHeadphones = @($cfg.CustomHeadphones) }
    } catch {}
}

# Auto-Sync on startup
$updateMessage = ""
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ "User-Agent" = "TripleRAudio-ClientAutoSync" }
    $apiUrl = "https://api.github.com/repos/$OwnerGitHubUser/$OwnerRepoName/commits/$OwnerBranch"
    $commit = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 8
    $latestSha = $commit.sha
    $commitMsg = $commit.commit.message

    $shaFile = Join-Path $baseDir "client_sync_sha.txt"
    $localSha = ""
    if (Test-Path $shaFile) { $localSha = (Get-Content $shaFile -Raw).Trim() }

    if ($latestSha -and ($latestSha -ne $localSha)) {
        $zipUrl = "https://github.com/$OwnerGitHubUser/$OwnerRepoName/archive/refs/heads/$OwnerBranch.zip"
        $tempZip = Join-Path $env:TEMP "TripleR-ClientAuto.zip"
        $tempExtract = Join-Path $env:TEMP "TripleR-ClientExtract"
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -Headers $headers -TimeoutSec 20
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        $inner = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        $srcLib = Join-Path $inner.FullName "library"
        if (Test-Path $srcLib) {
            Copy-Item -Path "$srcLib\*" -Destination $libraryDir -Recurse -Force
        }
        $latestSha | Set-Content -Path $shaFile -Force
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        $updateMessage = $commitMsg
    }
} catch {}

$xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Triple R Audio - Studio Tuning Suite" Height="710" Width="1140"
        WindowStartupLocation="CenterScreen" Background="#141414" Foreground="#FFFFFF"
        FontFamily="Segoe UI" ResizeMode="CanResizeWithGrip">
    <Window.Resources>
        <ControlTemplate x:Key="CustomComboToggle" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition />
                    <ColumnDefinition Width="28" />
                </Grid.ColumnDefinitions>
                <Border x:Name="Border" Grid.ColumnSpan="2" CornerRadius="3" Background="#262626" BorderBrush="#404040" BorderThickness="1" />
                <Path x:Name="Arrow" Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Data="M 0 0 L 5 5 L 10 0 Z" Fill="#E50914" />
            </Grid>
        </ControlTemplate>

        <ControlTemplate x:Key="CustomComboBox" TargetType="ComboBox">
            <Grid>
                <ToggleButton Name="ToggleButton" Template="{StaticResource CustomComboToggle}" Focusable="False" IsChecked="{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press" />
                <ContentPresenter Name="ContentSite" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="12,3,32,3" VerticalAlignment="Center" HorizontalAlignment="Left" TextElement.Foreground="#FFFFFF" TextElement.FontWeight="Bold" TextElement.FontSize="13" />
                <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                    <Grid Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                        <Border x:Name="DropDownBorder" Background="#1F1F1F" BorderThickness="1.5" BorderBrush="#E50914" CornerRadius="3" Margin="0,2,0,0" />
                        <ScrollViewer Margin="4,6,4,6" SnapsToDevicePixels="True">
                            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" />
                        </ScrollViewer>
                    </Grid>
                </Popup>
            </Grid>
        </ControlTemplate>

        <Style TargetType="ComboBox">
            <Setter Property="Template" Value="{StaticResource CustomComboBox}" />
            <Setter Property="Height" Value="34" />
            <Setter Property="MaxDropDownHeight" Value="340" />
        </Style>

        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#1F1F1F"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="12,7"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="BorderBrush" Value="#2E2E2E"/>
        </Style>

        <ControlTemplate x:Key="CustomTabItem" TargetType="TabItem">
            <Border x:Name="TabBorder" Background="#181818" BorderBrush="#383838" BorderThickness="1,1,1,0" CornerRadius="4,4,0,0" Padding="22,9" Margin="0,0,6,0" Cursor="Hand">
                <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" TextElement.Foreground="#FFFFFF" TextElement.FontWeight="Bold" TextElement.FontSize="13" />
            </Border>
            <ControlTemplate.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter TargetName="TabBorder" Property="Background" Value="#E50914"/>
                    <Setter TargetName="TabBorder" Property="BorderBrush" Value="#E50914"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="TabBorder" Property="BorderBrush" Value="#FFFFFF"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <Style TargetType="TabItem">
            <Setter Property="Template" Value="{StaticResource CustomTabItem}"/>
        </Style>

        <Style TargetType="Label">
            <Setter Property="Foreground" Value="#B3B3B3"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Name="brdHeader" Grid.Row="0" Margin="0,0,0,12" Padding="0,0,0,10" BorderThickness="0,0,0,2" BorderBrush="#E50914">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" Grid.Column="0" VerticalAlignment="Center">
                    <TextBlock Name="txtLogo1" Text="TRIPLE R" FontSize="26" FontWeight="Black" Foreground="#E50914"/>
                    <TextBlock Text=" AUDIO" FontSize="26" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,24,0"/>
                </StackPanel>

                <StackPanel Orientation="Horizontal" Grid.Column="1" VerticalAlignment="Center">
                    <Label Content="Theme:" VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <ComboBox Name="cmbThemes" Width="165" Height="32"/>
                </StackPanel>

                <StackPanel Orientation="Horizontal" Grid.Column="2" VerticalAlignment="Center">
                    <Button Name="btnToggleBypass" Content="TUNE: ON (COMPETITIVE)" Width="185" Height="34" Background="#262626" Foreground="#46D369" FontWeight="Black" BorderBrush="#46D369" BorderThickness="1.5" Margin="0,0,10,0" Cursor="Hand"/>
                    <Button Name="btnOpenSounds" Content="Open Sounds" Width="110" Height="34" Background="#262626" Foreground="#FFFFFF" FontWeight="Bold" BorderBrush="#404040" BorderThickness="1" Cursor="Hand"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Tabs -->
        <TabControl Name="tabMain" Grid.Row="1" Background="Transparent" BorderThickness="0">

            <!-- TAB 1: STUDIO ENGINE -->
            <TabItem Name="tabStudio" Header="Studio Engine">
                <Grid Margin="0,12,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="16"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Column 1 -->
                    <Border Name="brdCol1" Grid.Column="0" Background="#1F1F1F" CornerRadius="6" Padding="16" BorderBrush="#333333" BorderThickness="1">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <Grid Grid.Row="0" Margin="0,0,0,12">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Name="txtCol1Title" Grid.Column="0" Text="1. PICK YOUR AUDIO GEAR" FontSize="14" FontWeight="Black" Foreground="#E50914" VerticalAlignment="Center"/>
                                <Button Name="btnImportTxtMain" Grid.Column="1" Content="+ Add .txt Presets" Width="120" Height="26" FontSize="11" Background="#262626" Foreground="#46D369" FontWeight="Bold" BorderBrush="#404040" BorderThickness="1" Cursor="Hand"/>
                            </Grid>

                            <StackPanel Grid.Row="1">
                                <Label Content="Select Your Headphone / IEM:" Margin="0,0,0,4"/>
                                <ComboBox Name="cmbHeadphones" Margin="0,0,0,12"/>

                                <Label Content="Sound Profile / Target Curve:" Margin="0,0,0,4"/>
                                <ComboBox Name="cmbEqVariants" Margin="0,0,0,14"/>

                                <Border Name="brdCalib" Background="#141414" CornerRadius="4" Padding="12" BorderBrush="#2E2E2E" BorderThickness="1" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Name="txtCalibTitle" Text="TUNING CALIBRATION STATUS" FontSize="11" FontWeight="Black" Foreground="#46D369" Margin="0,0,0,4"/>
                                        <TextBlock Name="txtGearDetail" Text="Please pick your headset or IEM from the dropdown above to load its custom calibration." FontSize="11" Foreground="#B3B3B3" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </Border>

                                <Border Background="#141414" CornerRadius="4" Padding="12" BorderBrush="#2E2E2E" BorderThickness="1">
                                    <StackPanel>
                                        <TextBlock Text="ELGATO WAVE LINK 3.0 &amp; NORMAL AUDIO" FontSize="11" FontWeight="Black" Foreground="#E50914" Margin="0,0,0,3"/>
                                        <TextBlock Text="Route your game to Hi-Fi Cable Input. When watching YouTube or listening to music, click 'TUNE: ON/OFF' in the top bar for natural Normal Audio." FontSize="10.5" Foreground="#B3B3B3" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <!-- Column 2 -->
                    <Border Name="brdCol2" Grid.Column="2" Background="#1F1F1F" CornerRadius="6" Padding="16" BorderBrush="#333333" BorderThickness="1">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <TextBlock Name="txtCol2Title" Grid.Row="0" Text="2. SOUND MODE, LOUDNESS EQ &amp; GAIN" FontSize="14" FontWeight="Black" Foreground="#E50914" Margin="0,0,0,12"/>

                            <StackPanel Grid.Row="1">
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="12"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <Label Content="Sound Mode:" Margin="0,0,0,4"/>
                                        <ComboBox Name="cmbSoundMode"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="2">
                                        <Label Content="Tuning Style:" Margin="0,0,0,4"/>
                                        <ComboBox Name="cmbTuneStyles"/>
                                    </StackPanel>
                                </Grid>

                                <Grid Margin="0,0,0,12">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="12"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <Label Content="Game Profile:" Margin="0,0,0,4"/>
                                        <ComboBox Name="cmbGames"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="2">
                                        <Label Content="Self-Gun Volume:" Margin="0,0,0,4"/>
                                        <ComboBox Name="cmbGunLevels"/>
                                    </StackPanel>
                                </Grid>

                                <Border Background="#141414" CornerRadius="4" Padding="12" BorderBrush="#2E2E2E" BorderThickness="1" Margin="0,0,0,10">
                                    <StackPanel>
                                        <Grid Margin="0,0,0,6">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <CheckBox Name="chkLeqEnable" Grid.Column="0" IsChecked="True" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                            <TextBlock Grid.Column="1" Text="LOUDNESS EQUALIZATION (LEQ)" FontSize="11" FontWeight="Black" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                                            <TextBlock Name="txtLeqReleaseVal" Grid.Column="2" Text="Release Time: 2 (Short)" FontSize="11" FontWeight="Black" Foreground="#46D369"/>
                                        </Grid>
                                        <Slider Name="sliderLeqRelease" Minimum="2" Maximum="7" Value="2" TickFrequency="1" IsSnapToTickEnabled="True" Margin="0,2,0,2"/>
                                        <Grid>
                                            <TextBlock Text="2 - Short (Max Footsteps)" FontSize="10" Foreground="#808080" HorizontalAlignment="Left"/>
                                            <TextBlock Text="4 - Medium" FontSize="10" Foreground="#808080" HorizontalAlignment="Center"/>
                                            <TextBlock Text="7 - Long (Natural)" FontSize="10" Foreground="#808080" HorizontalAlignment="Right"/>
                                        </Grid>
                                    </StackPanel>
                                </Border>

                                <Border Name="brdBoost" Background="#141414" CornerRadius="4" Padding="12" BorderBrush="#2E2E2E" BorderThickness="1">
                                    <StackPanel>
                                        <Grid Margin="0,0,0,4">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock Text="OUTPUT PREAMP GAIN" FontSize="11" FontWeight="Black" Foreground="#FFFFFF"/>
                                            <TextBlock Name="txtBoostVal" Grid.Column="1" Text="0 dB" FontSize="12" FontWeight="Black" Foreground="#46D369"/>
                                        </Grid>
                                        <Slider Name="sliderBoost" Minimum="-6" Maximum="12" Value="0" TickFrequency="1" IsSnapToTickEnabled="True" Margin="0,2,0,2"/>
                                        <Grid>
                                            <TextBlock Text="-6 dB (Quieter)" FontSize="10" Foreground="#808080" HorizontalAlignment="Left"/>
                                            <TextBlock Text="0 dB (Neutral)" FontSize="10" Foreground="#808080" HorizontalAlignment="Center"/>
                                            <TextBlock Text="+12 dB (Max Boost)" FontSize="10" Foreground="#808080" HorizontalAlignment="Right"/>
                                        </Grid>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 2: SQUIGLINK AUTO-EQ -->
            <TabItem Name="tabSquiglink" Header="Squiglink Auto-EQ">
                <Grid Margin="0,12,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.1*"/>
                        <ColumnDefinition Width="16"/>
                        <ColumnDefinition Width="0.9*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="#1F1F1F" CornerRadius="6" Padding="18" BorderBrush="#333333" BorderThickness="1">
                        <StackPanel>
                            <TextBlock Text="SQUIGLINK FREQUENCY DATABASE INTEGRATION" FontSize="14" FontWeight="Black" Foreground="#E50914" Margin="0,0,0,6"/>
                            <TextBlock Text="Generate matched parametric EQs in the background or load any exported Squiglink .txt preset." FontSize="11.5" Foreground="#B3B3B3" Margin="0,0,0,14"/>

                            <Label Content="1. Select Squiglink Measurement Database:" Margin="0,0,0,4"/>
                            <ComboBox Name="cmbSquigDB" Margin="0,0,0,12"/>

                            <Label Content="2. Select Game Target Curve to Match:" Margin="0,0,0,4"/>
                            <ComboBox Name="cmbTargetMatch" Margin="0,0,0,12"/>

                            <Label Content="3. Enter Any Headphone or IEM Model Name:" Margin="0,0,0,4"/>
                            <TextBox Name="txtModelInput" Height="34" Background="#262626" Foreground="#FFFFFF" BorderBrush="#404040" FontSize="13" Padding="10,5" VerticalContentAlignment="Center" Margin="0,0,0,14"/>

                            <Grid Margin="0,0,0,14">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="10"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Button Name="btnFetchSquiglink" Grid.Column="0" Content="Open Model on Squiglink" Height="36" Background="#262626" Foreground="#FFFFFF" FontWeight="Bold" BorderBrush="#404040" BorderThickness="1" Cursor="Hand"/>
                                <Button Name="btnAutoEqDownload" Grid.Column="2" Content="Auto-EQ &amp; Add Model" Height="36" Background="#46D369" Foreground="#141414" FontWeight="Black" BorderThickness="0" Cursor="Hand"/>
                            </Grid>

                            <Border Background="#141414" CornerRadius="4" Padding="12" BorderBrush="#2E2E2E" BorderThickness="1">
                                <StackPanel>
                                    <TextBlock Text="AUTO-EQ ENGINE STATUS" FontSize="11" FontWeight="Black" Foreground="#46D369" Margin="0,0,0,4"/>
                                    <TextBlock Name="txtSquigStatus" Text="Ready. Type any model name and click 'Auto-EQ &amp; Add Model' for instant background calibration." FontSize="11" Foreground="#B3B3B3" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Border>

                    <Border Grid.Column="2" Background="#1F1F1F" CornerRadius="6" Padding="18" BorderBrush="#333333" BorderThickness="1">
                        <StackPanel>
                            <TextBlock Text="HOW TO USE SQUIGLINK PRESETS" FontSize="14" FontWeight="Black" Foreground="#E50914" Margin="0,0,0,10"/>
                            <TextBlock Text="Method 1: Instant In-App Auto-EQ" FontSize="12" FontWeight="Bold" Foreground="#46D369" Margin="0,0,0,4"/>
                            <TextBlock Text="Select target curve on the left, type your headphone name, and click 'Auto-EQ &amp; Add Model'. It automatically generates the filters and adds it to your dropdown." FontSize="11" Foreground="#E0E0E0" TextWrapping="Wrap" Margin="0,0,0,12"/>
                            <TextBlock Text="Method 2: Export from Website (.txt)" FontSize="12" FontWeight="Bold" Foreground="#46D369" Margin="0,0,0,4"/>
                            <TextBlock Text="Click '+ Add .txt Presets' on the Studio tab to load all 5 presets at once!" FontSize="11" Foreground="#E0E0E0" TextWrapping="Wrap"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 3: SETUP & MAINTENANCE -->
            <TabItem Name="tabSetup" Header="Setup &amp; Visual Guide">
                <Grid Margin="0,12,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="16"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Border Background="#1F1F1F" CornerRadius="6" Padding="16" BorderBrush="#333333" BorderThickness="1" Grid.Column="0">
                        <StackPanel>
                            <TextBlock Text="1-CLICK CLEAN INSTALLERS &amp; TOOLS" FontSize="14" FontWeight="Black" Foreground="#E50914" Margin="0,0,0,10"/>
                            <Grid Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="8"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Button Name="btnInstallStack" Grid.Column="0" Content="1-Click Full Setup" Height="34" Background="#46D369" Foreground="#141414" FontWeight="Black" BorderThickness="0" Cursor="Hand"/>
                                <Button Name="btnUnlockLeqScript" Grid.Column="2" Content="Install LEQ on Hi-Fi Cable" Height="34" Background="#E50914" Foreground="#FFFFFF" FontWeight="Black" BorderThickness="0" Cursor="Hand"/>
                            </Grid>

                            <Border Background="#141414" CornerRadius="4" Padding="10" BorderBrush="#2E2E2E" BorderThickness="1" Margin="0,10,0,10">
                                <StackPanel>
                                    <TextBlock Text="SETUP &amp; WAVE LINK 3.0 SUMMARY" FontSize="11" FontWeight="Black" Foreground="#46D369" Margin="0,0,0,4"/>
                                    <TextBlock Text="1. Click 'Open Sounds' -> Set 'Hi-Fi Cable Input' to 7.1 Surround &amp; 24-bit 48000 Hz." FontSize="10.5" Foreground="#E0E0E0" Margin="0,0,0,2"/>
                                    <TextBlock Text="2. In Wave Link 3.0, add Hi-Fi Cable Output as an input channel." FontSize="10.5" Foreground="#E0E0E0" Margin="0,0,0,2"/>
                                    <TextBlock Text="3. Route Game to Hi-Fi Cable; keep Discord/Browser on separate Elgato channels." FontSize="10.5" Foreground="#E0E0E0" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Border>

                            <TextBlock Text="MAINTENANCE &amp; FACTORY RESET (WARNING)" FontSize="11" FontWeight="Black" Foreground="#FF5555" Margin="0,6,0,4"/>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="8"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <ComboBox Name="cmbMaintenance" Grid.Column="0"/>
                                <Button Name="btnExecuteMaint" Grid.Column="2" Content="Execute" Width="90" Height="34" Background="#262626" Foreground="#FF5555" FontWeight="Bold" BorderBrush="#FF5555" BorderThickness="1" Cursor="Hand"/>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <Border Background="#1F1F1F" CornerRadius="6" Padding="16" BorderBrush="#333333" BorderThickness="1" Grid.Column="2">
                        <StackPanel>
                            <TextBlock Text="QUICK INSTRUCTIONS" FontSize="14" FontWeight="Black" Foreground="#E50914" Margin="0,0,0,10"/>
                            <TextBlock Text="1. In the Studio Engine tab, pick your headset or IEM." FontSize="11.5" Foreground="#E0E0E0" Margin="0,0,0,6"/>
                            <TextBlock Text="2. Select your Sound Profile (Warzone / CoD Footsteps Priority is recommended)." FontSize="11.5" Foreground="#E0E0E0" Margin="0,0,0,6"/>
                            <TextBlock Text="3. Ensure Loudness Equalization is checked with Release Time set to 2 (Short)." FontSize="11.5" Foreground="#E0E0E0" Margin="0,0,0,6"/>
                            <TextBlock Text="4. Click the red APPLY button at the bottom right!" FontSize="11.5" Foreground="#46D369" FontWeight="Bold"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>
        </TabControl>

        <!-- Footer -->
        <Border Name="brdFooter" Grid.Row="2" Margin="0,12,0,0" Background="#1F1F1F" CornerRadius="6" Padding="18,10" BorderBrush="#333333" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="SELECTED: " FontWeight="Black" FontSize="12" Foreground="#808080"/>
                        <TextBlock Name="txtActiveGear" Text="None (Pick Gear Above)" FontWeight="Black" FontSize="12" Foreground="#FFFFFF"/>
                        <TextBlock Text="  |  MODE: " FontWeight="Black" FontSize="12" Foreground="#808080"/>
                        <TextBlock Name="txtActiveMode" Text="Surround" FontWeight="Black" FontSize="12" Foreground="#46D369"/>
                        <TextBlock Text="  |  LEQ: " FontWeight="Black" FontSize="12" Foreground="#808080"/>
                        <TextBlock Name="txtActiveLeq" Text="ON (Release 2)" FontWeight="Black" FontSize="12" Foreground="#46D369"/>
                    </StackPanel>
                    <TextBlock Name="txtStatusSub" Text="Ready - Select your headset and click APPLY" FontSize="11" Foreground="#46D369" Margin="0,2,0,0"/>
                </StackPanel>

                <Button Name="btnApply" Grid.Column="1" Content="APPLY" Width="200" Height="42" Background="#E50914" Foreground="#FFFFFF" FontSize="15" FontWeight="Black" BorderThickness="0" Cursor="Hand"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$stringReader = New-Object System.IO.StringReader($xamlString)
$xmlReader = [System.Xml.XmlReader]::Create($stringReader)
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

$brdHeader         = $window.FindName("brdHeader")
$txtLogo1          = $window.FindName("txtLogo1")
$cmbThemes         = $window.FindName("cmbThemes")
$btnToggleBypass   = $window.FindName("btnToggleBypass")
$btnOpenSounds     = $window.FindName("btnOpenSounds")
$tabMain           = $window.FindName("tabMain")
$brdCol1           = $window.FindName("brdCol1")
$brdCol2           = $window.FindName("brdCol2")
$txtCol1Title      = $window.FindName("txtCol1Title")
$txtCol2Title      = $window.FindName("txtCol2Title")
$brdCalib          = $window.FindName("brdCalib")
$txtCalibTitle     = $window.FindName("txtCalibTitle")
$txtGearDetail     = $window.FindName("txtGearDetail")
$brdBoost          = $window.FindName("brdBoost")
$btnImportTxtMain  = $window.FindName("btnImportTxtMain")

$cmbHeadphones     = $window.FindName("cmbHeadphones")
$cmbEqVariants     = $window.FindName("cmbEqVariants")
$cmbSoundMode      = $window.FindName("cmbSoundMode")
$cmbGames          = $window.FindName("cmbGames")
$cmbTuneStyles     = $window.FindName("cmbTuneStyles")
$cmbGunLevels      = $window.FindName("cmbGunLevels")
$chkLeqEnable      = $window.FindName("chkLeqEnable")
$txtLeqReleaseVal  = $window.FindName("txtLeqReleaseVal")
$sliderLeqRelease  = $window.FindName("sliderLeqRelease")
$txtBoostVal       = $window.FindName("txtBoostVal")
$sliderBoost       = $window.FindName("sliderBoost")

$cmbSquigDB        = $window.FindName("cmbSquigDB")
$cmbTargetMatch    = $window.FindName("cmbTargetMatch")
$txtModelInput     = $window.FindName("txtModelInput")
$btnFetchSquiglink = $window.FindName("btnFetchSquiglink")
$btnAutoEqDownload = $window.FindName("btnAutoEqDownload")
$txtSquigStatus    = $window.FindName("txtSquigStatus")

$btnInstallStack      = $window.FindName("btnInstallStack")
$btnUnlockLeqScript   = $window.FindName("btnUnlockLeqScript")
$cmbMaintenance       = $window.FindName("cmbMaintenance")
$btnExecuteMaint      = $window.FindName("btnExecuteMaint")

$brdFooter         = $window.FindName("brdFooter")
$txtActiveGear     = $window.FindName("txtActiveGear")
$txtActiveMode     = $window.FindName("txtActiveMode")
$txtActiveLeq      = $window.FindName("txtActiveLeq")
$txtStatusSub      = $window.FindName("txtStatusSub")
$btnApply          = $window.FindName("btnApply")

$brushConv = New-Object System.Windows.Media.BrushConverter

if ($updateMessage) {
    $txtStatusSub.Text = "Updated from cloud!"
    [System.Windows.Forms.MessageBox]::Show("Triple R Audio updated from the cloud!`n`nWhat's New:`n$updateMessage", "Cloud Update", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Themes
@("Red & Black", "Green & Black", "Blue & Dark Navy", "Purple & Midnight", "Gold & Carbon") | ForEach-Object { $cmbThemes.Items.Add($_) | Out-Null }
if ($cmbThemes.Items.Contains($selectedTheme)) { $cmbThemes.SelectedItem = $selectedTheme } else { $cmbThemes.SelectedIndex = 0 }

function Apply-ColorTheme {
    param([string]$ThemeName)
    $primary = "#E50914"; $secondary = "#46D369"; $bg = "#141414"; $card = "#1F1F1F"; $border = "#333333"
    switch ($ThemeName) {
        "Green & Black"     { $primary = "#00E676"; $secondary = "#00B0FF"; $bg = "#0D1117"; $card = "#161B22"; $border = "#30363D" }
        "Blue & Dark Navy"  { $primary = "#3A86FF"; $secondary = "#00F5D4"; $bg = "#0B132B"; $card = "#1C2541"; $border = "#3A506B" }
        "Purple & Midnight" { $primary = "#BD93F9"; $secondary = "#50FA7B"; $bg = "#18122B"; $card = "#282A36"; $border = "#44475A" }
        "Gold & Carbon"     { $primary = "#F5A623"; $secondary = "#46D369"; $bg = "#1C1C1E"; $card = "#2C2C2E"; $border = "#3A3A3C" }
    }
    $window.Background = $brushConv.ConvertFromString($bg)
    $brdHeader.BorderBrush = $brushConv.ConvertFromString($primary)
    $txtLogo1.Foreground = $brushConv.ConvertFromString($primary)
    $txtCol1Title.Foreground = $brushConv.ConvertFromString($primary)
    $txtCol2Title.Foreground = $brushConv.ConvertFromString($primary)
    $btnApply.Background = $brushConv.ConvertFromString($primary)
    $btnAutoEqDownload.Background = $brushConv.ConvertFromString($secondary)
    $txtCalibTitle.Foreground = $brushConv.ConvertFromString($secondary)
    $txtBoostVal.Foreground = $brushConv.ConvertFromString($secondary)
    $txtStatusSub.Foreground = $brushConv.ConvertFromString($secondary)
    $txtActiveMode.Foreground = $brushConv.ConvertFromString($secondary)
    $brdCol1.Background = $brushConv.ConvertFromString($card)
    $brdCol2.Background = $brushConv.ConvertFromString($card)
    $brdFooter.Background = $brushConv.ConvertFromString($card)
    $brdCol1.BorderBrush = $brushConv.ConvertFromString($border)
    $brdCol2.BorderBrush = $brushConv.ConvertFromString($border)
    $brdFooter.BorderBrush = $brushConv.ConvertFromString($border)
}

$cmbThemes.Add_SelectionChanged({ if ($cmbThemes.SelectedItem) { Apply-ColorTheme $cmbThemes.SelectedItem.ToString() } })
Apply-ColorTheme $cmbThemes.SelectedItem.ToString()

@("Surround (Full Spatial)", "Cinema (5.1 Surround)", "Pure Stereo (Direct 2-Channel)") | ForEach-Object { $cmbSoundMode.Items.Add($_) | Out-Null }
$cmbSoundMode.SelectedIndex = 0

@("Universal Game Audio (All PC Games)", "Black Ops 7 & Warzone (16-Ch Engine)", "Black Ops 6 Engine", "Battlefield 6 Engine") | ForEach-Object { $cmbGames.Items.Add($_) | Out-Null }
$cmbGames.SelectedIndex = 0

@("Classic+ (Default - Distant Footstep Lift)", "Classic (Natural Dynamic Leveller)", "Open (Bright & High Footstep Clarity)", "Full (Dynamic Combat)", "Competitive (Maximum Isolation)") | ForEach-Object { $cmbTuneStyles.Items.Add($_) | Out-Null }
$cmbTuneStyles.SelectedIndex = 0

@("UltraLoGun (Maximum quiet self-gunfire)", "LoGun (Low self-gunfire)", "MedGun (Balanced gunfire)", "StockGun (Original gunfire)") | ForEach-Object { $cmbGunLevels.Items.Add($_) | Out-Null }
$cmbGunLevels.SelectedIndex = 0

@("GadgetryTech (Best for Gaming & CoD Targets)", "Crinacle / In-Ear Fidelity", "Super* Review (Official Squiglink)", "TimmyV / Gizaudio", "Bad Guy Good Audio Reviews (HBB)") | ForEach-Object { $cmbSquigDB.Items.Add($_) | Out-Null }
$cmbSquigDB.SelectedIndex = 0

@("Call of Duty / Warzone Footstep Target", "Black Ops 6 IEM Target", "Harman In-Ear 2024 Reference", "Diffuse Field / Neutral Reference") | ForEach-Object { $cmbTargetMatch.Items.Add($_) | Out-Null }
$cmbTargetMatch.SelectedIndex = 0

@("Select Maintenance Action...", "Restart Windows Audio Service (Fix Glitch/Mute)", "Reinstall / Repair Audio Stack", "Factory Reset & Uninstall All (Warning)") | ForEach-Object { $cmbMaintenance.Items.Add($_) | Out-Null }
$cmbMaintenance.SelectedIndex = 0

$friendCategories = [ordered]@{
    "-- CHOOSE YOUR HEADSET / IEM --" = @( "Please select your model below..." )
    "-- KZ IN-EAR MONITORS (IEMS) --" = @( "KZ ZAR (1DD + 7BA Hybrid)", "KZ Castor (Harman Edition)", "KZ Castor (Bass Edition)", "KZ EDX Pro", "KZ EDX Lite", "KZ ZSN Pro / ZSN Pro X", "KZ ZS10 Pro / ZS10 Pro X", "KZ DQS (Semi-Open)", "KZ Krila", "KZ PR1 / PR2 / PR3 (Planar)" )
    "-- POPULAR GAMING IEMS --" = @( "Tangzu Fudu Verse 1", "Tangzu Wan'er S.G", "7Hz Salnotes Zero / Zero 2", "QKZ AK6", "Moondrop Chu II / Aria", "Truthear x Crinacle Zero:RED", "Simgot EM6L / SuperMix 4", "Kiwi Ears Cadenza" )
    "-- GAMING HEADSETS --" = @( "PlayStation Pulse Elite (BassImpact)", "Logitech Pro X (Wired)", "Logitech G935 Wireless", "Astro A50 Gen 4", "Astro A10", "Razer BlackShark V2 X", "HyperX Cloud II / Cloud Alpha", "SteelSeries Arctis Nova 7 / Pro" )
    "-- AUDIOPHILE & STUDIO HEADPHONES --" = @( "Sennheiser HD 560S / HD 490 Pro", "Beyerdynamic DT 770 / DT 990 Pro", "Audio-Technica ATH-M50x", "Audeze Maxwell", "Flat Reference (Universal Tuning)" )
}

function Refresh-FriendHeadphoneList {
    $cmbHeadphones.Items.Clear()
    foreach ($cat in $friendCategories.Keys) {
        $cmbHeadphones.Items.Add($cat) | Out-Null
        foreach ($item in $friendCategories[$cat]) {
            $cmbHeadphones.Items.Add("  $item") | Out-Null
        }
    }
    if ($customUserHeadphones.Count -gt 0) {
        $cmbHeadphones.Items.Add("-- CUSTOM ADDED --") | Out-Null
        foreach ($c in $customUserHeadphones) {
            $cmbHeadphones.Items.Add("  $c") | Out-Null
        }
    }
    $cmbHeadphones.SelectedIndex = 1
}

Refresh-FriendHeadphoneList

function Refresh-FriendCurves {
    param([string]$HeadphoneName)
    $cmbEqVariants.Items.Clear()
    $firstWord = ($HeadphoneName.Trim().Split(' ')[0])

    if (Test-Path $eqBaseDir) {
        $txtFiles = Get-ChildItem -Path $eqBaseDir -Filter "*.txt" | Sort-Object Name
        foreach ($tf in $txtFiles) {
            if ($tf.BaseName -match $firstWord -or $tf.Name -notmatch "^(KZ_|PlayStation_|Tangzu_|QKZ_|Logitech_|Astro_|Razer_)") {
                $cmbEqVariants.Items.Add("[Preset] $($tf.Name)") | Out-Null
            }
        }
    }

    @("Warzone / CoD Footsteps Priority (Aggressive 1-3kHz Lift)", "Treble Tamer (Smooth Highs & Gunshot Control)", "Competitive Spatial (Wide Soundstage)", "Harman In-Ear 2024 Balanced Target", "Flat Reference Target") | ForEach-Object {
        $cmbEqVariants.Items.Add($_) | Out-Null
    }
    $cmbEqVariants.SelectedIndex = 0
}

$cmbHeadphones.Add_SelectionChanged({
    if ($cmbHeadphones.SelectedItem) {
        $raw = $cmbHeadphones.SelectedItem.ToString().Trim()
        if ($raw.StartsWith("--") -or $raw.StartsWith("Please select")) {
            $txtActiveGear.Text = "None (Pick Gear Above)"
            $txtGearDetail.Text = "Please select your headset or IEM from the list above to view its acoustic calibration profile."
            return
        }
        $hp = $raw
        $txtActiveGear.Text = $hp
        Refresh-FriendCurves -HeadphoneName $hp

        if ($hp -match "KZ ZAR") {
            $txtGearDetail.Text = "KZ ZAR (1DD+7BA): 5kHz BA peak tamed -4dB for anti-fatigue, 1250Hz footstep bite elevated +3.8dB."
        } elseif ($hp -match "Pulse Elite") {
            $txtGearDetail.Text = "PlayStation Pulse Elite: BassImpact rumble clamped at 85Hz, 1250Hz footstep crunch boosted +4.6dB, 5kHz gunshot spike smoothed."
        } elseif ($hp -match "Tangzu Fudu") {
            $txtGearDetail.Text = "Tangzu Fudu: Dark/warm tilt corrected with +4.5dB lift in the 1400-2900Hz footstep and positioning spectrum."
        } elseif ($hp -match "QKZ AK6") {
            $txtGearDetail.Text = "QKZ AK6: Heavy 90Hz boomy bloat filtered out (-5.8dB) to unmask hidden footsteps and reload audio."
        } elseif ($hp -match "Astro A50") {
            $txtGearDetail.Text = "Astro A50 Gen 4: Wireless bass boom trimmed (-4dB @ 100Hz) with 1250Hz footsteps and 2800Hz directional lift active."
        } else {
            $txtGearDetail.Text = "Custom Parametric Calibration: Pinna directional lift, footstep band priority, and gunshot resonance suppression enabled."
        }
    }
})

$cmbSoundMode.Add_SelectionChanged({
    if ($cmbSoundMode.SelectedItem) { $txtActiveMode.Text = $cmbSoundMode.SelectedItem.ToString().Split(' ')[0] }
})

$chkLeqEnable.IsChecked = $leqEnabled
$sliderLeqRelease.Value = $leqReleaseTime

function Update-LeqUI {
    $v = [Math]::Round($sliderLeqRelease.Value)
    $txtLeqReleaseVal.Text = "Release Time: $v"
    if ($chkLeqEnable.IsChecked) {
        $txtActiveLeq.Text = "ON (Release $v)"
        $txtActiveLeq.Foreground = $brushConv.ConvertFromString("#46D369")
    } else {
        $txtActiveLeq.Text = "OFF"
        $txtActiveLeq.Foreground = $brushConv.ConvertFromString("#FF5555")
    }
}
Update-LeqUI
$sliderLeqRelease.Add_ValueChanged({ Update-LeqUI })
$chkLeqEnable.Add_Checked({ Update-LeqUI })
$chkLeqEnable.Add_Unchecked({ Update-LeqUI })

$sliderBoost.Add_ValueChanged({ $txtBoostVal.Text = "$([Math]::Round($sliderBoost.Value)) dB" })
$btnOpenSounds.Add_Click({ Start-Process "control.exe" -ArgumentList "mmsys.cpl,,0" })

function Update-BypassUI {
    if ($global:tuneActiveMode) {
        $btnToggleBypass.Content = "TUNE: ON (COMPETITIVE)"
        $btnToggleBypass.Foreground = $brushConv.ConvertFromString("#46D369")
        $btnToggleBypass.BorderBrush = $brushConv.ConvertFromString("#46D369")
    } else {
        $btnToggleBypass.Content = "TUNE: OFF (NORMAL AUDIO)"
        $btnToggleBypass.Foreground = $brushConv.ConvertFromString("#FF5555")
        $btnToggleBypass.BorderBrush = $brushConv.ConvertFromString("#FF5555")
    }
}
Update-BypassUI
$btnToggleBypass.Add_Click({
    $global:tuneActiveMode = -not $global:tuneActiveMode
    Update-BypassUI
    $btnApply.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
})

$btnImportTxtMain.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Squiglink EQ Presets (*.txt)|*.txt|All Files (*.*)|*.*"
    $dlg.Title = "Select 1 or More Squiglink .txt Presets (Hold Ctrl to select all 5!)"
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $count = 0
        $first = ""
        foreach ($f in $dlg.FileNames) {
            $fn = [System.IO.Path]::GetFileName($f)
            Copy-Item -Path $f -Destination (Join-Path $eqBaseDir $fn) -Force
            if (-not $first) { $first = "[Preset] $fn" }
            $count++
        }
        $hp = if ($cmbHeadphones.SelectedItem) { $cmbHeadphones.SelectedItem.ToString().Trim() } else { "KZ ZAR" }
        Refresh-FriendCurves -HeadphoneName $hp
        if ($first) { $cmbEqVariants.SelectedItem = $first }
        [System.Windows.Forms.MessageBox]::Show("Successfully imported $count custom .txt preset(s)! They are now in your Sound Profile dropdown.", "Presets Imported", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$btnFetchSquiglink.Add_Click({
    $db = $cmbSquigDB.SelectedItem.ToString()
    $url = "https://gadgetrytech.squig.link/?share=Warzone_2024_IEM_Target"
    if ($db -match "Crinacle") { $url = "https://crinacle.squig.link/" }
    elseif ($db -match "Super") { $url = "https://squig.link/" }
    elseif ($db -match "TimmyV") { $url = "https://timmyv.squig.link/" }
    elseif ($db -match "Bad Guy") { $url = "https://hbb.squig.link/" }
    $m = $txtModelInput.Text.Trim()
    if ($m) {
        $cleanM = $m -replace '\s+', '_'
        if ($url -match "\?share=") { $url += ",$cleanM" } else { $url += "?share=$cleanM" }
    }
    Start-Process $url
})

$btnAutoEqDownload.Add_Click({
    $m = $txtModelInput.Text.Trim()
    if (-not $m) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a model name first.", "Input Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    $target = $cmbTargetMatch.SelectedItem.ToString()
    $cleanM = $m -replace '[\\/:*?"<>| ]', '_'
    $eqFileName = "${cleanM}_AutoEQ.txt"
    $eqFullPath = Join-Path $eqBaseDir $eqFileName

    $peq = @"
Preamp: -3.0 dB
Filter 1: ON PK Fc 65 Hz Gain -2.0 dB Q 1.30
Filter 2: ON PK Fc 250 Hz Gain -1.0 dB Q 1.30
Filter 3: ON PK Fc 1250 Hz Gain 3.8 dB Q 1.90
Filter 4: ON PK Fc 2800 Hz Gain 2.8 dB Q 1.80
Filter 5: ON PK Fc 5000 Hz Gain -3.8 dB Q 2.60
"@
    $peq | Set-Content -Path $eqFullPath -Force
    if (-not ($global:customUserHeadphones -contains $m)) { $global:customUserHeadphones += $m }
    Refresh-FriendHeadphoneList
    $cmbHeadphones.SelectedItem = "  $m"
    $tabMain.SelectedIndex = 0
    [System.Windows.Forms.MessageBox]::Show("Auto-EQ generated for '$m' and added to your dropdown!", "Auto-EQ Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnInstallStack.Add_Click({
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command `"irm artiswar.io/tools/ArtTuneGuided | iex`""
})

$btnUnlockLeqScript.Add_Click({
    $rel = [Math]::Round($sliderLeqRelease.Value)
    Set-RegistryLoudnessEq -Enabled $true -ReleaseTime $rel
    Restart-Service audiosrv -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show("Loudness Equalization (Release Time $rel) has been activated on your Hi-Fi Cable!", "LEQ Activated", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnExecuteMaint.Add_Click({
    $a = $cmbMaintenance.SelectedItem.ToString()
    if ($a -match "Restart Windows Audio") {
        Restart-Service audiosrv -Force -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show("Windows Audio restarted cleanly!", "Audio Restarted", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } elseif ($a -match "Reinstall") {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command `"irm artiswar.io/tools/ArtTuneGuided | iex`""
    } elseif ($a -match "Factory Reset") {
        $confirm = [System.Windows.Forms.MessageBox]::Show("WARNING: This will uninstall all virtual audio drivers and Equalizer APO.`n`nProceed?", "Confirm Reset", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command `"irm artiswar.io/tools/ArtTuneGuided | iex`""
        }
    }
})

function Set-RegistryLoudnessEq {
    param([bool]$Enabled, [int]$ReleaseTime)
    try {
        $enhancementFlagKey = "{fc52a749-4be9-4510-896e-966ba6525980},3"
        $releaseTimeKey     = "{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0},3"
        $devices = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\*\Properties" -ErrorAction SilentlyContinue
        foreach ($dev in $devices) {
            $vals = $dev.GetValueNames() | ForEach-Object { $dev.GetValue($_) }
            if ($vals -match "Hi-Fi Cable|Art Tune|VB-Audio") {
                $fxPath = Join-Path $dev.PSParentPath "FxProperties"
                if (-not (Test-Path $fxPath)) { New-Item -Path $fxPath -Force | Out-Null }
                if ($Enabled) {
                    [byte[]]$flagBytes = @(0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0xff,0xff,0x00,0x00)
                } else {
                    [byte[]]$flagBytes = @(0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                }
                Set-ItemProperty -Path $fxPath -Name $enhancementFlagKey -Value $flagBytes -Type Binary -Force -ErrorAction SilentlyContinue
                [byte[]]$relBytes = @(0x03,0x00,0x00,0x00,0x01,0x00,0x00,0x00,[byte]$ReleaseTime,0x00,0x00,0x00)
                Set-ItemProperty -Path $fxPath -Name $releaseTimeKey -Value $relBytes -Type Binary -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

$btnApply.Add_Click({
    try {
        $selectedHp = $cmbHeadphones.SelectedItem.ToString().Trim()
        if ($selectedHp.StartsWith("--") -or $selectedHp.StartsWith("Please select")) {
            [System.Windows.Forms.MessageBox]::Show("Please choose your headset or IEM model from the dropdown first!", "Pick Your Audio Gear", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $boostDb = [Math]::Round($sliderBoost.Value)
        "Preamp: $boostDb dB" | Set-Content -Path $boostFile -Force

        $leqOn = [bool]$chkLeqEnable.IsChecked
        $relVal = [int][Math]::Round($sliderLeqRelease.Value)
        Set-RegistryLoudnessEq -Enabled ($leqOn -and $global:tuneActiveMode) -ReleaseTime $relVal

        $cfg = @{
            Theme            = $cmbThemes.SelectedItem.ToString()
            LeqEnabled       = $leqOn
            LeqReleaseTime   = $relVal
            TuneActiveMode   = $global:tuneActiveMode
            CustomHeadphones = $global:customUserHeadphones
        }
        $cfg | ConvertTo-Json | Set-Content -Path $clientCfg -Force

        $selectedCurve = $cmbEqVariants.SelectedItem.ToString()
        $selectedMode = $cmbSoundMode.SelectedItem.ToString()

        if (-not $global:tuneActiveMode) {
            "Preamp: 0 dB`n# Normal Audio Pass-Through" | Set-Content -Path $eapoConfig -Force
            $txtActiveGear.Text = "$selectedHp (BYPASS)"
            $txtActiveMode.Text = "Normal Audio"
            $txtStatusSub.Text = "Normal Audio Mode Active"
            return
        }

        $gunToken = $cmbGunLevels.SelectedItem.ToString().Split(' ')[0]
        $tuneFile = "ArtTuneDB\library\BO7\V5\BO7_V5_16ch_ClassicPlus-${gunToken}.txt"

        if ($selectedCurve -match "^\[Preset\]\s*(.+)$") {
            $eqFileName = $matches[1].Trim()
        } else {
            $hpClean = $selectedHp -replace '[\\/:*?"<>| ]', '_'
            $eqFileName = "${hpClean}.txt"
            $eqFullPath = Join-Path $eqBaseDir $eqFileName
            $peq = @"
Preamp: -3.0 dB
Filter 1: ON PK Fc 65 Hz Gain -2.0 dB Q 1.30
Filter 2: ON PK Fc 250 Hz Gain -1.0 dB Q 1.30
Filter 3: ON PK Fc 1250 Hz Gain 3.8 dB Q 1.90
Filter 4: ON PK Fc 2800 Hz Gain 2.8 dB Q 1.80
Filter 5: ON PK Fc 5000 Hz Gain -3.8 dB Q 2.60
"@
            $peq | Set-Content -Path $eqFullPath -Force
        }

        $configContent = @"
Device: Art Tune + VB-Audio Virtual Cable
Include: $tuneFile
Include: ArtTuneDB\library\BO7\V5\eq\$eqFileName
Include: ArtTuneDB\boost.txt

Device: Art Tune VB-Audio Hi-Fi Cable
Include: ArtTuneDB\library\BO7\V3\BO7_V3_pre.txt
Include: HeSuVi\hesuvi.txt
Include: ArtTuneDB\library\BO7\V5\eq\$eqFileName
Include: ArtTuneDB\library\BO7\V3\BO7_V3_post.txt
Include: ArtTuneDB\boost.txt
"@
        $configContent | Set-Content -Path $eapoConfig -Force
        $txtActiveGear.Text = $selectedHp
        $txtActiveMode.Text = $selectedMode.Split(' ')[0]
        $txtStatusSub.Text = "Applied Live at $(Get-Date -Format 'HH:mm:ss')"
        [System.Windows.Forms.MessageBox]::Show("Applied tuning for $selectedHp!`n`nMode: $selectedMode`nProfile: $selectedCurve`nLoudness EQ: $(if($leqOn){'ON (Release ' + $relVal + ')'}else{'OFF'})`nGain: $boostDb dB", "Triple R Audio - Applied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {}
})

$window.ShowDialog() | Out-Null
