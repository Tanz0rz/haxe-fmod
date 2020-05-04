package faxe;

enum FaxeEvent {
    MUSIC_STOPPED;
}

interface FaxeEventListener {
    public function ReceiveEvent(faxeEvent:FaxeEvent):Void;
}