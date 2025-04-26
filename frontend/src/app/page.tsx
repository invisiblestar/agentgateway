'use client';

import React, { useState, useEffect } from 'react';
import { Container, Box, Typography, Grid } from '@mui/material';
import LogsWindow from './components/LogsWindow';
import { websocketService } from './services/websocket';
import Chat from '../components/Chat';

export default function Home() {
    const [logs, setLogs] = useState<string[]>([]);

    useEffect(() => {
        const handleLog = (log: string) => {
            setLogs(prevLogs => [...prevLogs, log].slice(-100)); // Keep last 100 logs
        };

        websocketService.addListener(handleLog);

        return () => {
            websocketService.removeListener(handleLog);
        };
    }, []);

    return (
        <Container maxWidth="xl">
            <Box sx={{ my: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    Agent Gateway
                </Typography>
                
                <Grid container spacing={2} sx={{ height: 'calc(100vh - 120px)' }}>
                    <Grid item xs={12} md={6} sx={{ height: '100%' }}>
                        <Chat />
                    </Grid>
                    <Grid item xs={12} md={6} sx={{ height: '100%' }}>
                        <LogsWindow logs={logs} />
                    </Grid>
                </Grid>
            </Box>
        </Container>
    );
} 