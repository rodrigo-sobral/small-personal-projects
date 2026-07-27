import React, { useState } from "react";
import Card from "react-bootstrap/Card";
import Form from "react-bootstrap/Form";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/Col";
import Button from "react-bootstrap/Button";

const AddLogItem = ({ onAdd }) => {
    const [text, setText] = useState('');
    const [user, setUser] = useState('');
    const [priority, setPriority] = useState('low');

    const handleSubmit = (e) => {
        e.preventDefault();
        onAdd({ text, priority, user, created: new Date().toString() });
        setText('');
        setPriority('low');
        setUser('');
    };

    return (
        <Card className="mb-3 mt-5">
            <Card.Body>
                <Form onSubmit={handleSubmit}>
                    <Row className="my-3">
                        <Col>
                            <Form.Group controlId="logText">
                                <Form.Control
                                    type="text"
                                    placeholder="Enter log text"
                                    value={text}
                                    onChange={(e) => setText(e.target.value)}
                                />
                            </Form.Group>
                        </Col>
                        <Col>
                            <Form.Group controlId="logUser">
                                <Form.Control
                                    type="text"
                                    placeholder="Enter user name"
                                    value={user}
                                    onChange={(e) => setUser(e.target.value)}
                                />
                            </Form.Group>
                        </Col>
                    </Row>
                    <Row className="mt-3">
                        <Col>
                            <Form.Group controlId="logPriority">
                                <Form.Select
                                    value={priority}
                                    onChange={(e) => setPriority(e.target.value)}
                                >
                                    <option value="low">Low</option>
                                    <option value="moderate">Moderate</option>
                                    <option value="high">High</option>
                                </Form.Select>
                            </Form.Group>
                        </Col>
                        <Col className="d-flex align-items-end">
                            <Button variant="primary" type="submit" className="w-100">
                                Add Log
                            </Button>
                        </Col>
                    </Row>
                </Form>
            </Card.Body>
        </Card>
    );
}

export default AddLogItem;