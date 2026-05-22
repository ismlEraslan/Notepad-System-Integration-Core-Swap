A lightweight, zero-dependency batch script designed to cleanly swap the default Windows 11 Notepad app with a native Win32 Notepad++ installation. Instead of relying on fragile user-level file associations that easily reset during Windows updates, this tool implements a system-wide configuration to route all text-editing tasks directly through Notepad++.
How It Works

    Removes Default Notepad: Completely uninstalls the modern Windows Notepad package (Microsoft.WindowsNotepad) across all system profiles to prevent conflicting handlers.

    Intercepts Executable Calls: Uses an Image File Execution Options (IFEO) debugger entry to hook notepad.exe. When the system or a third-party tool attempts to launch the stock text editor, the Windows kernel transparently reroutes the file arguments straight into Notepad++.

    Maintains Stock Aesthetics: Formats the system file association classes (Notepad++_txt) to pull the modern, minimalist blank-document asset directly from %SystemRoot%\System32\imageres.dll,-102. Text files keep their native, clean Windows 11 appearance.

    Restores "New Text Document": Rewrites the standard ShellNew registry directives so that right-clicking in Windows Explorer and selecting New -> Text Document continues to function perfectly.

    Architecture-Aware Execution: Targets the native 64-bit system registry hive to ensure configuration stability across the entire operating system.

Environment Support

    OS: Windows 10 & 11

    Architecture: x64

    Execution: Run as Administrator (.bat)

Simple, factual, and completely ignores the fact that any files were harmed or any registries were virtualized in the making of it. Ready to ship!
