import Quickshell
import "./components/ipc"

ShellRoot {
    LauncherIpc {}

    Variants {
        model: Quickshell.screens

        ScreenShell {}
    }
}
