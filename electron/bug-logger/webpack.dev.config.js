const webpack = require('webpack');
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const { spawn } = require('child_process');

module.exports = {
  mode: 'development',
  target: 'electron-renderer',
  entry: './src/index.js', // Adjust as needed
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'bundle.js'
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader']
      },
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        use: [{ loader: 'babel-loader', options: { compact: false } }]
      },
      {
        test: /\.(jpe?g|png|gif)$/i,
        type: 'asset/resource',
        generator: {
          filename: 'img/[name]__[hash][ext][query]'
        }
      },
      {
        test: /\.(eot|svg|ttf|woff|woff2)$/i,
        type: 'asset/resource',
        generator: {
          filename: 'font/[name]__[hash][ext][query]'
        }
      }
    ]
  },
  plugins: [
    new HtmlWebpackPlugin({ title: 'BugLogger' }),
    new webpack.DefinePlugin({
      'process.env.NODE_ENV': JSON.stringify('development')
    })
  ],
  devtool: 'cheap-source-map',
  devServer: {
    static: {
      directory: path.resolve(__dirname, 'dist')
    },
    hot: true,
    onBeforeSetupMiddleware() {
      spawn('electron', ['.'], {
        shell: true,
        env: {
			...process.env,
			NODE_OPTIONS: ''
		},
        stdio: 'inherit'
      })
        .on('close', () => process.exit(0))
        .on('error', (err) => console.error(err));
    }
  }
};
