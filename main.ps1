[Byte]$Width = 50
[Byte]$Height = 30

function Record-Host-State()
{
    $global:hostWindowSize      = $Host.UI.RawUI.WindowSize
    $global:hostWindowPosition  = $Host.UI.RawUI.WindowPosition 
    $global:hostBufferSize      = $Host.UI.RawUI.BufferSize    
    $global:hostTitle           = $Host.UI.RawUI.WindowTitle    
    $global:hostBackground      = $Host.UI.RawUI.BackgroundColor    
    $global:hostForeground      = $Host.UI.RawUI.ForegroundColor
    $global:hostCursorSize      = $Host.UI.RawUI.CursorSize
    $global:hostCursorPosition  = $Host.UI.RawUI.CursorPosition
    $global:hostCursorVisible   = [Console]::CursorVisible
    
    #Store the full buffer
    $rectClass = "System.Management.Automation.Host.Rectangle" 
    $bufferRect = new-object $rectClass 0, 0, $global:hostBufferSize.width, 
    $global:hostBufferSize.height
    $global:hostBuffer = $Host.UI.RawUI.GetBufferContents($bufferRect)
}
function Restore-Host-State()
{
    $Host.UI.RawUI.CursorSize       = $global:hostCursorSize
    $Host.UI.RawUI.BufferSize       = $global:hostBufferSize
    $Host.UI.RawUI.WindowSize       = $global:hostWindowSize
    $Host.UI.RawUI.WindowTitle      = $global:hostTitle
    $Host.UI.RawUI.BackgroundColor  = $global:hostBackground
    $Host.UI.RawUI.ForegroundColor  = $global:hostForeground
    [Console]::CursorVisible        = $global:hostCursorVisible
    
    $pos = $Host.UI.RawUI.WindowPosition
    $pos.x = 0
    $pos.y = 0
    #First restore the contents of the buffer and then reposition the cursor
    $Host.UI.RawUI.SetBufferContents($pos, $global:hostBuffer)
    $Host.UI.RawUI.CursorPosition = $global:hostCursorPosition
}

function Main {
    if ($psISE) { #ISE Console is not fully featured by design.
        throw "Sorry, this program will not run correctly in Powershell ISE Console"
        break 
    } 
    Record-Host-State
    [Console]::CursorVisible = $False
    try {
        Game-State
    } finally {
        Restore-Host-State
    }
}

function Game-State {

    Enum State {
        Standing
        Dodging
        Attacking
    }
    Class GameEntity {
        [int]$x
        [int]$y
        [Char]$character

        [void]Left() { $this.x-- }
        [void]Right() { $this.x++ }
        [void]Up() { $this.y-- }
        [void]Down() { $this.y++ }
        [void]SetX($newX) { $this.x = $newX }
        [void]SetY($newY) { $this.y = $newY }
        [void]SetChar($newChar) { $this.character = $newChar }
        [void]Draw() { $global:Buffer[$this.y][$this.x] = $this.character.ToString() }
    }
    Class PlayerEntity : GameEntity {
        [State]$state = [State]::Standing
        [void]ChangeCharacter([Object]$Character) { 
            
        }
    }
    $player = New-Object PlayerEntity
    $player.character = 'Y'
    $player.SetX(25)
    $player.SetY(15)

    do {
        Start-Sleep -m 17
        $key = Read-Character
        Handle-Input $key
        Update-Field $Buffer
        Draw-Field $Buffer
    } while ($true)
}

function Read-Character()
{
    if ($host.ui.RawUI.KeyAvailable) {
        return $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
    }
   
    return $null
}

function Update-Field() {
    $global:Buffer = 1..$Height | ForEach-Object { ,(,"." * $Width) }
    $player.Draw()
}

function Draw-Field($Buffer) {
    $string = ""
    foreach ($y in $Buffer) {
        foreach ($x in $y) {
            $string += $x
        }
        $string += [Environment]::NewLine
    }
    Clear-Host
    Write-Host $string
}

function Handle-Input($key) {
    if ($key -ne $null) {
        switch -regex ($key.Character) {
            "w" { $player.Up() }
            "s" { $player.Down() }
            "a" { $player.Left() }
            "d" { $player.Right() }
        }
        if ($key.VirtualKeycode -eq 27) { break } #Escape to quit
    }
}

. Main
