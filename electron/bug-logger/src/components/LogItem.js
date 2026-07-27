import React from "react";
import Button from "react-bootstrap/Button";
import Badge from "react-bootstrap/Badge";

const LogItem = ({ log: { _id, priority, text, user, created }, onDelete }) => {
    return (
        <tr>
            <td><Badge className="p-2" bg={priority === "high" ? "danger" : priority === "moderate" ? "warning" : "success"}>{priority.charAt(0).toUpperCase() + priority.slice(1)}</Badge></td>
            <td>{text}</td>
            <td>{user}</td>
            <td>{new Date(created).toLocaleString()}</td>
            <td>
                <Button variant="danger" onClick={() => onDelete(_id)}>X</Button>
            </td>
        </tr>
    );
};

export default LogItem;
