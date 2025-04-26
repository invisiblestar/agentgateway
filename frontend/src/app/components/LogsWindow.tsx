'use client';

import React, { useEffect, useRef } from 'react';
import { Box, Paper, Typography } from '@mui/material';

interface LogsWindowProps {
    logs: string[];
}

const LogsWindow: React.FC<LogsWindowProps> = ({ logs }) => {
    const logsEndRef = useRef<HTMLDivElement>(null);

    const scrollToBottom = () => {
        logsEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };

    useEffect(() => {
        scrollToBottom();
    }, [logs]);

    return (
        <Paper 
            elevation={3} 
            sx={{ 
                p: 2, 
                height: '100%', 
                overflow: 'auto',
                backgroundColor: '#1e1e1e',
                color: '#fff',
                fontFamily: 'monospace'
            }}
        >
            <Typography variant="h6" sx={{ mb: 2, color: '#fff' }}>
                Backend Logs
            </Typography>
            <Box sx={{ whiteSpace: 'pre-wrap' }}>
                {logs.map((log, index) => (
                    <div key={index} style={{ marginBottom: '4px' }}>
                        {log}
                    </div>
                ))}
                <div ref={logsEndRef} />
            </Box>
        </Paper>
    );
};

export default LogsWindow; 