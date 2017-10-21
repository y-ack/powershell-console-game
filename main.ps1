 #From https://www.codeproject.com/articles/241411/powershell-falling-blocks-ascii-art-on-the-move
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
    } catch {
        Write-Host $_.Exception -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red

        Write-Host "An Error occurred.  Press x to debug or any other key to continue."
        $temp = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($temp.character -eq "x") {
            do {
                $input = Read-Host -Prompt ">>"
                Invoke-Expression $input
            } while ($input -ne "quit")
        }
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
        [bool]$collides = $true
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black

        [void]Update() {}
    }
    Class CreatureEntity : GameEntity {
        [State]$state = [State]::Standing
        [double]$VelocityX
        [double]$VelocityY

        [void]ChangeCharacter([Object]$Character) { 
            
        }
        [void]Update() {
            $this.x += $this.VelocityX
            $this.VelocityX -= $this.VelocityX.CompareTo(0.0)
            $this.y += $this.VelocityY
            $this.VelocityY -= $this.VelocityY.CompareTo(0.0)
        }
    }

    Class GameBuffer {
        [System.Management.Automation.Host.BufferCell[,]]$Buffer
        [Byte]$Width = 50
        [Byte]$Height = 30
        [char]$BlankChar = '.'
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
        [Collections.ArrayList]$EntityList = (New-Object System.Collections.ArrayList<>);


        [void]SetBuffer($NewContents) {
            $this.Buffer = $NewContents
        }
        [void]Set([GameEntity]$e) {
            $this.Buffer[$e.y,$e.x] =
                [System.Management.Automation.Host.BufferCell]::new(
                    $e.character,
                    $e.ForegroundColor,
                    $e.BackgroundColor, 
                    [System.Management.Automation.Host.BufferCellType]::Complete
                )
        }
        [void]RegisterEntity($e) {
            $this.EntityList.Add($e)
        }
        [void]Update() {
            $this.EntityList | ForEach-Object {
                $_.Update()
                $this.Set($_)
            }
        }

        [System.Management.Automation.Host.BufferCell]GetBlankCell() {
            return [System.Management.Automation.Host.BufferCell]::new(
                        $this.BlankChar,
                        $this.ForegroundColor,
                        $this.BackgroundColor, 
                        [System.Management.Automation.Host.BufferCellType]::Complete
                    )
        }
    }

    $player = New-Object CreatureEntity
    $player.character = 'Y'
    $player.x = 24
    $player.y = 14
    $player.ForegroundColor = [ConsoleColor]::Green

    $Buffer = New-Object GameBuffer
    $Buffer.RegisterEntity($player)

    do {
        Start-Sleep -m 17 #TODO: find a better VSYNC?
        $key = Read-Character
        Handle-Input $key
        Update-Field $Buffer
        Draw-Field $Buffer
    } while ($true)
}

function Read-Character()
{
    if ($host.ui.RawUI.KeyAvailable) {
        return $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
   
    return $null
}

function Update-Field([GameBuffer]$Buffer) {
    #We cannot access $Host from within $Buffer, nor can we pass it.
    $Buffer.SetBuffer($Host.Ui.RawUI.NewBufferCellArray($Buffer.Width, $Buffer.Height, $Buffer.GetBlankCell()))
    $Buffer.Update()
}

function Draw-Field([GameBuffer]$Buffer) {
    Clear-Host
    $Host.UI.RawUI.SetBufferContents([System.Management.Automation.Host.Coordinates]::new(0,0), $Buffer.Buffer)
}

function Handle-Input($key) {
    if ($key -ne $null) {
        switch -regex ($key.Character) {
            "w" { $player.VelocityY -= 1 }
            "s" { $player.VelocityY += 1 }
            "a" { $player.VelocityX -= 1 }
            "d" { $player.VelocityX += 1 }
        }
        if ($key.VirtualKeycode -eq 27) { break } #Escape to quit
    }
}

. Main
