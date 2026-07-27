const mongoose = require('mongoose');

const LogSchema = new mongoose.Schema({
    text: {
        type: String,
        trim: true,
        minlength: [5, 'Log text must be at least 5 characters long'],
        maxlength: [500, 'Log text cannot exceed 500 characters'],
        validate: {
            validator: (v) => typeof v === 'string' && v.trim().length > 0,
            message: (props) => `${props.value} is not a valid log text. It must be a non-empty string.`,
        },
        required: [true, 'Log text is required'],
    },
    user: {
        type: String,
        trim: true,
        minlength: [3, 'User must be at least 3 characters long'],
        maxlength: [50, 'User cannot exceed 50 characters'],
        default: 'Anonymous',
        validate: {
            validator: (v) => /^[a-zA-Z0-9\s]+$/.test(v),
            message: (props) => `${props.value} is not a valid username. Only alphanumeric characters and spaces are allowed.`,
        },
        required: [true, 'User is required'],
    },
    priority: {
        type: String,
        enum: ['low', 'moderate', 'high'],
        default: 'low',
        validate: {
            validator: (v) => ['low', 'moderate', 'high'].includes(v),
            message: (props) => `${props.value} is not a valid priority. Valid values are low, moderate, high.`,
        },
        required: [true, 'Priority is required'],
    },
    created: {
        type: Date,
        default: Date.now,
        validate: {
            validator: (v) => v instanceof Date && !isNaN(v.getTime()),
            message: 'Invalid date format',
        },
        required: [true, 'Date is required'],
    }
});

module.exports = mongoose.model('Log', LogSchema);