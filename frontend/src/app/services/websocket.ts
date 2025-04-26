class WebSocketService {
    private ws: WebSocket | null = null;
    private listeners: ((data: string) => void)[] = [];

    constructor() {
        this.connect();
    }

    private connect() {
        this.ws = new WebSocket('ws://localhost:8000/ws/logs');

        this.ws.onmessage = (event) => {
            const data = event.data;
            this.notifyListeners(data);
        };

        this.ws.onclose = () => {
            console.log('WebSocket connection closed. Reconnecting...');
            setTimeout(() => this.connect(), 1000);
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }

    public addListener(listener: (data: string) => void) {
        this.listeners.push(listener);
    }

    public removeListener(listener: (data: string) => void) {
        this.listeners = this.listeners.filter(l => l !== listener);
    }

    private notifyListeners(data: string) {
        this.listeners.forEach(listener => listener(data));
    }
}

export const websocketService = new WebSocketService(); 