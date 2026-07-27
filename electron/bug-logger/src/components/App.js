import React, { useState, useEffect } from 'react';
import Container from 'react-bootstrap/Container';
import Table from 'react-bootstrap/Table';
import LogItem from './LogItem';
import AddLogItem from './AddLogItem';
import Alert from 'react-bootstrap/Alert';
import { ipcRenderer } from 'electron';


const App = () => {
	const [logs, setLogs] = useState([]);
	const [alert, setAlert] = useState({ show: false, message: '', variant: 'success' });

	const handleAdd = (log) => {
		if (!log.text || !log.user) {
			showAlert("Please fill in all fields", "danger");
			return;
		}
		ipcRenderer.invoke('logs:add', log)
		showAlert("Log added successfully", "success");
	};
	const handleDelete = (id) => {
		ipcRenderer.invoke('logs:delete', id)
		showAlert("Log deleted successfully", "danger");
	};

	const showAlert = (message, variant = 'success', seconds = 2) => {
		setAlert({ show: true, message, variant });
		setTimeout(() => setAlert({ show: false, message: '', variant: 'success' }), seconds * 1000);
	};

	useEffect(() => {
		ipcRenderer.send("logs:load");

		ipcRenderer.on("logs:get", (e, logs) => setLogs(JSON.parse(logs)));
		ipcRenderer.on("logs:clear", () => {
			setLogs([]);
			setAlert("Logs cleared");
		});
	}, []);

	return (
		<Container>
			<h1 className="mt-5">Bug Logger</h1>
			<AddLogItem onAdd={handleAdd} />
			{alert.show && <Alert variant={alert.variant} className="mt-3">{alert.message}</Alert>}
			<Table striped bordered hover>
				<thead>
					<tr>
						<th>Priority</th>
						<th>Log Text</th>
						<th>User</th>
						<th>Created</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					{logs.map((log) => (
						<LogItem key={log._id} log={log} onDelete={() => handleDelete(log._id)} />
					))}
				</tbody>
			</Table>
		</Container>
	);
};

export default App;
