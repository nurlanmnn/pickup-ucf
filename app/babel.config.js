module.exports = function (api) {
    api.cache(true);
    return {
      presets: ['babel-preset-expo'],
      plugins: [
        // IMPORTANT: Reanimated plugin must be last
        'react-native-reanimated/plugin',
      ],
    };
  };
  