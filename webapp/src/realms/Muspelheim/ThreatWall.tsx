import React from 'react';
import { Table, Tag, Space, Typography, Card } from 'antd';
import { WarningOutlined, FireOutlined, ShieldOutlined } from '@ant-design/icons';

const { Title, Text } = Typography;

const ThreatWall = () => {
  const threats = [
    { id: 'T-01', source: 'Void-Siphon', severity: 'CRITICAL', status: 'ACTIVE', impact: 'Kernel Instability', entropy: '89%' },
    { id: 'T-02', source: 'Fenrir-Burst', severity: 'HIGH', status: 'CONTAINED', impact: 'Bus Latency', entropy: '42%' },
    { id: 'T-03', source: 'Surtur-Singe', severity: 'MODERATE', status: 'MONITORING', impact: 'Thermal Throttle', entropy: '15%' },
  ];

  const getSeverityColor = (sev: string) => {
    switch (sev) {
      case 'CRITICAL': return 'volcano';
      case 'HIGH': return 'error';
      case 'MODERATE': return 'warning';
      default: return 'default';
    }
  };

  return (
    <div style={{ padding: '24px', backgroundColor: '#0a0a0a', minHeight: '100vh', color: '#e0e0e0' }}>
      <Card 
        title={<Title level={3} style={{ color: '#ff4d4f' }}><FireOutlined /> Muspelheim Threat-Wall</Title>} 
        style={{ backgroundColor: '#1a1a1a', border: '1px solid #ff4d4f', borderRadius: '8px' }}
      >
        <Text style={{ color: '#aaa', marginBottom: '20px', display: 'block' }}>
          Real-time entropy monitoring of the Hybrid Microkernel Matrix.
        </Text>
        
        <Table 
          dataSource={threats} 
          pagination={false}
          columns={[
            { title: 'ID', dataIndex: 'id', key: 'id', render: (text) => <Text strong style={{ color: '#00f2ff' }}>{text}</Text> },
            { title: 'Source', dataIndex: 'source', key: 'source' },
            { 
              title: 'Severity', 
              dataIndex: 'severity', 
              key: 'severity', 
              render: (sev) => <Tag color={getSeverityColor(sev)}>{sev}</Tag> 
            },
            { 
              title: 'Status', 
              dataIndex: 'status', 
              key: 'status', 
              render: (status) => (
                <Space>
                  <ShieldOutlined style={{ color: status === 'ACTIVE' ? '#ff4d4f' : '#52c41a' }} />
                  {status}
                </Space>
              )
            },
            { title: 'Impact', dataIndex: 'impact', key: 'impact' },
            { title: 'Entropy', dataIndex: 'entropy', key: 'entropy', render: (val) => <Text style={{ color: '#ff99cc' }}>{val}</Text> },
          ]}
        />
      </Card>
    </div>
  );
};

export default ThreatWall;
