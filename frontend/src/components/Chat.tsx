'use client';

import React, { useState } from 'react';
import { Box, TextField, Button, Paper, Typography } from '@mui/material';

interface Message {
  text: string;
  isResponse: boolean;
}

const Chat: React.FC = () => {
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<Message[]>([]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim()) return;

    // Add user message
    setMessages(prev => [...prev, { text: input, isResponse: false }]);

    try {
      const response = await fetch('http://localhost:8000/api/query', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ query: input }),
      });

      const data = await response.json();
      
      let responseText;
      if (typeof data.response === 'object' && data.response !== null) {
        // If the backend returns {output, reasoning}
        responseText = data.response.output;
        if (data.response.reasoning) {
          responseText += `\n\nReasoning: ${data.response.reasoning}`;
        }
      } else {
        responseText = data.response;
      }
      setMessages(prev => [...prev, { text: responseText, isResponse: true }]);
    } catch (error) {
      console.error('Error:', error);
      setMessages(prev => [...prev, { text: 'Error processing request', isResponse: true }]);
    }

    setInput('');
  };

  return (
    <Paper 
      elevation={3} 
      sx={{ 
        height: '100%', 
        display: 'flex', 
        flexDirection: 'column',
        p: 2
      }}
    >
      <Box sx={{ 
        flexGrow: 1, 
        overflowY: 'auto',
        mb: 2,
        display: 'flex',
        flexDirection: 'column',
        gap: 1
      }}>
        {messages.map((message, index) => (
          <Box
            key={index}
            sx={{
              alignSelf: message.isResponse ? 'flex-start' : 'flex-end',
              maxWidth: '70%',
              bgcolor: message.isResponse ? 'grey.100' : 'primary.main',
              color: message.isResponse ? 'text.primary' : 'white',
              p: 2,
              borderRadius: 2
            }}
          >
            <Typography>{message.text}</Typography>
          </Box>
        ))}
      </Box>
      
      <Box component="form" onSubmit={handleSubmit} sx={{ display: 'flex', gap: 1 }}>
        <TextField
          fullWidth
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Type your message..."
          variant="outlined"
          size="small"
        />
        <Button type="submit" variant="contained">
          Send
        </Button>
      </Box>
    </Paper>
  );
};

export default Chat; 