package com.youlai.mall.oms.controller.admin;

import com.youlai.common.result.Result;
import com.youlai.mall.oms.dto.OrderInfoDTO;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import javax.annotation.Resource;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Slf4j
class OmsOrderControllerTest {
    @Resource
    private OmsOrderController omsOrderController;
    @BeforeEach
    void setUp() {
    }

    @AfterEach
    void tearDown() {
    }

    @Test
    void getOrderInfo() {
        Result<OrderInfoDTO> orderInfo = omsOrderController.getOrderInfo(1L);
        Assertions.assertEquals(orderInfo.getData().getStatus(), 101);
    }
}
