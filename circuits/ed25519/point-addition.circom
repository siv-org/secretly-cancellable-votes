pragma circom 2.0.0;

// Include appropriate add, subtract and multiply templates
include "chunkedmul.circom";
include "chunkedadd.circom";
include "modulus.circom";

template PointAdd(){
    // Points are represented as tuples (X, Y, Z, T) of extended coordinates, with x = X/Z, y = Y/Z, x*y = T/Z

    var constant_neg_d[3] = [36453506357546404448470858, 34096743896386538864219637, 13898602798132607198219823];
    var constant_d[3] = [2232119870121729142126755, 4588882331281594726377994, 24787023429535526392377808];
    var i;
    var base = 85;

    signal input P[4][3];
    signal input Q[4][3];
    signal output R[4][3];

    component X_1X_2 = ChunkedMul(3, 3, base);
    component Y_1Y_2 = ChunkedMul(3, 3, base);
    component X_1Y_2 = ChunkedMul(3, 3, base);
    component X_2Y_1 = ChunkedMul(3, 3, base);
    component T_1T_2 = ChunkedMul(3, 3, base);
    component Z_1Z_2 = ChunkedMul(3, 3, base);

    for (i = 0; i < 3; i++) {
        X_1X_2.in1[i] <== P[0][i];
        X_1X_2.in2[i] <== Q[0][i];

        Y_1Y_2.in1[i] <== P[1][i];
        Y_1Y_2.in2[i] <== Q[1][i];
        
        X_1Y_2.in1[i] <== P[0][i];
        X_1Y_2.in2[i] <== Q[1][i];
        
        X_2Y_1.in1[i] <== P[1][i];
        X_2Y_1.in2[i] <== Q[0][i];

        T_1T_2.in1[i] <== P[3][i];
        T_1T_2.in2[i] <== Q[3][i];

        Z_1Z_2.in1[i] <== P[2][i];
        Z_1Z_2.in2[i] <== Q[2][i];
    }

    component T_1T_2_d = ChunkedMul(6, 3, base);
    component T_1T_2_neg_d = ChunkedMul(6, 3, base);

    for (i = 0; i < 2 * 3; i++) {
        T_1T_2_d.in1[i] <== T_1T_2.out[i];
        T_1T_2_neg_d.in1[i] <== T_1T_2.out[i];
    }

    for (i = 0; i < 3; i++ ) {
        T_1T_2_d.in2[i] <== constant_d[i];
        T_1T_2_neg_d.in2[i] <== constant_neg_d[i];
    }
    // component mod_X_1X_2 = ModulusWith25519Chunked51(2*5);
    // component mod_Y_1Y_2 = ModulusWith25519Chunked51(2*5);
    // component mod_X_1Y_2 = ModulusWith25519Chunked51(2*5);
    // component mod_X_2Y_1 = ModulusWith25519Chunked51(2*5);
    // component mod_Z_1Z_2 = ModulusWith25519Chunked51(2*5);

    // for(i=0;i<2*5;i++){
    //     mod_X_1X_2.a[i] <== X_1X_2.out[i];
    //     mod_Y_1Y_2.a[i] <== Y_1Y_2.out[i];
    //     mod_X_1Y_2.a[i] <== X_1Y_2.out[i];
    //     mod_X_2Y_1.a[i] <== X_2Y_1.out[i];
    //     mod_Z_1Z_2.a[i] <== Z_1Z_2.out[i];
    // }


    // component mod_T_1T_2_d = ModulusWith25519Chunked51(2*5+5);
    // component mod_T_1T_2_neg_d = ModulusWith25519Chunked51(2*5+5);

    // for(i=0;i<2*5+5;i++){
    //     mod_T_1T_2_d.a[i] <== T_1T_2_d.out[i];
    //     mod_T_1T_2_neg_d.a[i] <== T_1T_2_neg_d.out[i];
    // }

    component e_add = ChunkedAdd(6,2,base);
    component f_add = ChunkedAdderIrregular(9,6,base);
    component g_add = ChunkedAdderIrregular(9,6,base);
    component h_add = ChunkedAdd(6,2,base);
    
    for(i=0;i<6;i++){
        e_add.in[0][i] <== X_1Y_2.out[i];
        e_add.in[1][i] <== X_2Y_1.out[i];
        f_add.b[i] <== Z_1Z_2.out[i];  
        g_add.b[i] <== Z_1Z_2.out[i];
        h_add.in[0][i] <== X_1X_2.out[i];
        h_add.in[1][i] <== Y_1Y_2.out[i];  
    }

    for(i=0;i<9;i++){
        f_add.a[i] <== T_1T_2_neg_d.out[i];
        g_add.a[i] <== T_1T_2_d.out[i];
    }

    component final_mul1 = ChunkedMul(10, 7, base);
    component final_mul2 = ChunkedMul(10, 7, base);
    component final_mul3 = ChunkedMul(10, 10, base);
    component final_mul4 = ChunkedMul(7, 7, base);

    for(i=0;i<7;i++){
        final_mul1.in2[i] <== e_add.out[i];
        final_mul2.in2[i] <== h_add.out[i];
        final_mul4.in1[i] <== e_add.out[i];
        final_mul4.in2[i] <== h_add.out[i];
    }

    for(i=0;i<10;i++){
        final_mul1.in1[i] <== f_add.sum[i];
        final_mul2.in1[i] <== g_add.sum[i];
        final_mul3.in1[i] <== f_add.sum[i];
        final_mul3.in2[i] <== g_add.sum[i];
    }

    component final_modulo1 = ModulusWith25519Chunked51(17);
    component final_modulo2 = ModulusWith25519Chunked51(17);
    component final_modulo3 = ModulusWith25519Chunked51(20);
    component final_modulo4 = ModulusWith25519Chunked51(14);

    for(i=0;i<17;i++){
        final_modulo1.in[i] <== final_mul1.out[i];
        final_modulo2.in[i] <== final_mul2.out[i];
    }

    for(i=0;i<20;i++){
        final_modulo3.in[i] <== final_mul3.out[i];
    }

    for(i=0;i<14;i++){
        final_modulo4.in[i] <== final_mul4.out[i];
    }
    
    for(i=0;i<3;i++){
        R[0][i] <== final_modulo1.out[i];
        R[1][i] <== final_modulo2.out[i];
        R[2][i] <== final_modulo3.out[i];
        R[3][i] <== final_modulo4.out[i];    
    }
}

template DoublePt(){
    signal input P[4][3];
    signal output out_2P[4][3];
    component double = PointAdd();
    var i;
    for(i=0;i<3;i++){
        double.P[0][i] <== P[0][i];
        double.P[1][i] <== P[1][i];
        double.P[2][i] <== P[2][i];
        double.P[3][i] <== P[3][i];

        double.Q[0][i] <== P[0][i];
        double.Q[1][i] <== P[1][i];
        double.Q[2][i] <== P[2][i];
        double.Q[3][i] <== P[3][i];
    }
    for(i=0;i<3;i++){
        double.R[0][i] ==> out_2P[0][i];
        double.R[1][i] ==> out_2P[1][i];
        double.R[2][i] ==> out_2P[2][i];
        double.R[3][i] ==> out_2P[3][i];
    }
}
