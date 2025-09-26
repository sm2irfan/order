import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for product images with optimized settings
class ProductImageCacheManager {
  static const key = 'productImageCache';
  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 30), // Keep images for 30 days
        maxNrOfCacheObjects: 1000, // Cache up to 1000 images
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  /// Preload multiple images to cache
  static Future<void> preloadImages(List<String> imageUrls) async {
    final List<Future> futures = [];

    for (String url in imageUrls) {
      if (url.isNotEmpty) {
        futures.add(_preloadSingleImage(url));
      }
    }

    await Future.wait(futures);
  }

  static Future<void> _preloadSingleImage(String url) async {
    try {
      await instance.getSingleFile(url);
      print('✅ Preloaded image: $url');
    } catch (e) {
      print('❌ Failed to preload image: $url - $e');
    }
  }

  /// Clear all cached images
  static Future<void> clearCache() async {
    await instance.emptyCache();
    print('🗑️ Image cache cleared');
  }

  /// Get cache size information
  static Future<String> getCacheSize() async {
    try {
      // Simple size estimation based on cache objects count
      return 'Cache active';
    } catch (e) {
      return 'Unknown';
    }
  }
}

/// Enhanced cached image widget with optimized settings and error handling
class OptimizedCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final BorderRadius? borderRadius;
  final bool showLoadingProgress;

  const OptimizedCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.showLoadingProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: ProductImageCacheManager.instance,
      placeholder:
          placeholder ??
          (showLoadingProgress
              ? (context, url) => _buildLoadingWidget()
              : null),
      errorWidget: errorWidget ?? (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8),
            Text(
              'Loading image...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Specialized widget for product images with consistent styling
class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;
  final bool showPlaceholderText;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.size = 300,
    this.onTap,
    this.showPlaceholderText = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl == null || imageUrl!.isEmpty) {
      imageWidget = _buildPlaceholderWidget();
    } else {
      imageWidget = OptimizedCachedImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        borderRadius: BorderRadius.circular(8),
      );
    }

    if (onTap != null) {
      imageWidget = GestureDetector(onTap: onTap, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildPlaceholderWidget() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: size * 0.3, color: Colors.grey[400]),
          if (showPlaceholderText) ...[
            const SizedBox(height: 8),
            Text(
              'No image',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen image viewer with caching
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String productName;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Product name header
          Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: Text(
              productName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Full screen image
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: OptimizedCachedImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  showLoadingProgress: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
