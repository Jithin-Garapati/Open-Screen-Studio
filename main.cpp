#include <opencv2/opencv.hpp>
#include <iostream>

int main()
{
    cv::Mat image = cv::imread("test.jpg");
    
    if (image.empty()) {
        std::cout << "Error: Could not load image" << std::endl;
        return -1;
    }

    cv::imshow("Test Window", image);
    cv::waitKey(0);
    
    return 0;
} 